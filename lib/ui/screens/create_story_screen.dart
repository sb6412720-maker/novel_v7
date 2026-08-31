import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/api_service.dart';
import 'edit_chapter_screen.dart';

/// Mobile "New Story" screen matching the dark HTML prototype:
/// cover upload, draft readiness meter, title/summary counters,
/// genre + New, Ongoing/Completed status, language, audience,
/// content-warning chips, max-3 hashtags, sticky Save Draft / Publish.
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({
    super.key,
    required this.apiService,
    this.story,
    this.authorDisplayName,
  });

  final ApiService apiService;
  final Map<String, dynamic>? story;
  final String? authorDisplayName;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  // Light theme (default for New Story / story creation page)
  static const Color _ink = Color(0xFFFAF8F5); // page background
  static const Color _panel = Color(0xFFFFFFFF); // cards
  static const Color _panelAlt = Color(0xFFF5F3F0); // secondary surfaces
  static const Color _border = Color(0xFFE8E8E8);
  static const Color _borderSoft = Color(0xFFEDEAE6);
  static const Color _textHi = Color(0xFF231F20); // primary text
  static const Color _textLo = Color(0xFF767676); // secondary text
  static const Color _textFaint = Color(0xFF9A9A9A);
  static const Color _magenta = Color(0xFF581845); // brand
  static const Color _violet = Color(0xFF8B5CF6);
  static const Color _amber = Color(0xFFF0B357);
  static const Color _green = Color(0xFF4FD1A5);

  static const List<String> _defaultGenres = [
    'Romance', 'Fantasy', 'Drama', 'Horror', 'Mystery', 'Adventure',
    'Poetry', 'Slice of Life', 'Fanfiction', 'Thriller', 'Sci-Fi',
    'Young Adult', 'Humor', 'Paranormal', 'Action', 'Other',
  ];
  static const List<String> _languages = ['Sinhala', 'English', 'Tamil'];
  static const List<String> _audiences = ['All Ages', 'Teen (13+)', 'Mature (18+)'];
  static const List<String> _warningOptions = [
    'Violence', 'Strong Language', 'Sexual Content', 'Drug/Alcohol Use', 'Death', 'Other',
  ];

  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _authorController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _otherWarningController = TextEditingController();
  final _customGenreController = TextEditingController();
  final _tagFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  bool _saving = false;
  String _coverPath = '';
  final List<String> _selectedTags = [];
  List<String> _availableTags = const [];
  bool _loadingTags = false;

  List<String> _genres = List<String>.from(_defaultGenres);
  String? _selectedGenre;
  bool _loadingGenres = false;
  bool _showCustomGenre = false;

  String _status = 'Draft';
  String _language = 'Sinhala';
  String? _audience;
  final Set<String> _selectedWarnings = {};

  bool get _isEditing => widget.story != null;

  int get _readinessDone {
    var n = 0;
    if (_coverPath.isNotEmpty) n++;
    if (_titleController.text.trim().length > 2) n++;
    if (_summaryController.text.trim().length > 20) n++;
    if ((_selectedGenre ?? '').trim().isNotEmpty) n++;
    if ((_audience ?? '').trim().isNotEmpty) n++;
    return n;
  }

  int get _readinessPct => ((_readinessDone / 5) * 100).round();

  String get _readinessCaption {
    if (_readinessPct == 0) return 'A blank page. Where will it begin?';
    if (_readinessPct < 100) return 'Still inking the details in';
    return 'Ready for readers';
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.story!['title']?.toString() ?? '';
      _summaryController.text = widget.story!['description']?.toString() ?? '';
      final warningsRaw = (widget.story!['content_warnings'] ?? widget.story!['contentWarnings'] ?? '').toString();
      if (warningsRaw.isNotEmpty) {
        for (final part in warningsRaw.split(RegExp(r'[,;]'))) {
          final t = part.trim();
          if (t.isEmpty) continue;
          final match = _warningOptions.firstWhere(
            (w) => w.toLowerCase() == t.toLowerCase(),
            orElse: () => '',
          );
          if (match.isNotEmpty) {
            _selectedWarnings.add(match);
          } else {
            _selectedWarnings.add('Other');
            _otherWarningController.text = t;                                                                          
          }
        }
      }
      final g = (widget.story!['genre'] ?? widget.story!['primary_genre'] ?? '').toString().trim();
      if (g.isNotEmpty) {
        _selectedGenre = g;
        if (!_genres.any((x) => x.toLowerCase() == g.toLowerCase())) {
          _genres = [..._genres, g];
        }
      }
      final st = (widget.story!['status_text'] ?? '').toString().toLowerCase();
      if (st.contains('complete') || st.contains('finished')) {
        _status = 'Completed';
      }
      final lang = (widget.story!['language'] ?? '').toString().trim();
      if (lang.isNotEmpty) _language = lang;
      final aud = (widget.story!['audience'] ?? '').toString().trim();
      if (aud.isNotEmpty) _audience = aud;
      _coverPath = widget.story!['cover_path']?.toString() ?? '';
      final existing = (widget.story!['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
      _selectedTags.addAll(existing.take(3));
    }
    _titleController.addListener(() => setState(() {}));
    // Length counter uses ValueListenableBuilder — avoid setState (was stealing focus)
    _resolveAuthorName();
    _loadAvailableTags();
    if (_isEditing) {
      unawaited(_hydrateFromServer());
    }
    _loadGenres();
  }

  Future<void> _resolveAuthorName() async {
    String name = (widget.authorDisplayName ?? '').trim();
    if (name.isEmpty) {
      try {
        final me = await widget.apiService.fetchMe();
        name = (me['display_name'] ?? me['username'] ?? me['name'] ?? '').toString().trim();
      } catch (_) {}
    }
    if (name.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        name = (prefs.getString('auth_display_name') ?? '').trim();
      } catch (_) {}
    }
    if (name.isEmpty && _isEditing) {
      name = widget.story!['author']?.toString().trim() ?? '';
    }
    if (name.isEmpty) name = 'Author';
    if (!mounted) return;
    setState(() => _authorController.text = name);
  }

  Future<void> _loadAvailableTags() async {
    setState(() => _loadingTags = true);
    try {
      final items = await widget.apiService.fetchTags();
      if (!mounted) return;
      setState(() {
        _availableTags = items
            .map((e) => (e['name'] ?? e['tag'] ?? e['label'] ?? '').toString())
            .where((t) => t.isNotEmpty)
            .map((t) => t.startsWith('#') ? t.substring(1) : t)
            .toList();
        _loadingTags = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTags = false);
    }
  }

  Future<void> _loadGenres() async {
    setState(() => _loadingGenres = true);
    try {
      final remote = await widget.apiService.fetchGenres();
      if (!mounted) return;
      final merged = <String>{..._defaultGenres};
      for (final g in remote) {
        final s = g.trim();
        if (s.isNotEmpty) merged.add(s);
      }
      if (_selectedGenre != null && _selectedGenre!.isNotEmpty) {
        merged.add(_selectedGenre!);
      }
      final list = merged.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _genres = list;
        _loadingGenres = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingGenres = false);
    }
  }

  Future<void> _pickCover() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final result = await widget.apiService.uploadWriterImage(bytes, picked.name);
      final path = (result['path'] ?? result['cover_path'] ?? result['url'] ?? '').toString();
      if (!mounted) return;
      if (path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover upload returned empty path')),
        );
        return;
      }
      setState(() => _coverPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cover uploaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cover upload failed: $e')),
      );
    }
  }

  Future<void> _addCustomGenre() async {
    var name = _customGenreController.text.trim();
    if (name.isEmpty) return;
    try {
      name = await widget.apiService.createGenre(name);
    } catch (_) {}
    if (!mounted) return;
    final exists = _genres.any((g) => g.toLowerCase() == name.toLowerCase());
    setState(() {
      if (!exists) {
        _genres = [..._genres, name]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
      _selectedGenre = _genres.firstWhere(
        (g) => g.toLowerCase() == name.toLowerCase(),
        orElse: () => name,
      );
      _showCustomGenre = false;
      _customGenreController.clear();
    });
  }

  void _addTag(String raw) {
    var name = raw.trim();
    if (name.startsWith('#')) name = name.substring(1);
    if (name.isEmpty) return;
    // Authors cannot invent hashtags — must pick an admin-created tag.
    String? match;
    for (final t in _availableTags) {
      if (t.toLowerCase() == name.toLowerCase()) {
        match = t;
        break;
      }
    }
    if (match == null || match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only admin hashtags can be used. Type to see suggestions, then pick one.',
          ),
        ),
      );
      return;
    }
    final tagName = match; // promote to non-null String for analyzer
    if (_selectedTags.any((t) => t.toLowerCase() == tagName.toLowerCase())) {
      return;
    }
    if (_selectedTags.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 hashtags per story')),
      );
      return;
    }
    setState(() {
      _selectedTags.add(tagName);
      _tagInputController.clear();
    });
  }

  void _removeTag(String name) => setState(() => _selectedTags.remove(name));

  String _buildWarningsString() {
    final parts = <String>[];
    for (final w in _selectedWarnings) {
      if (w == 'Other') {
        final other = _otherWarningController.text.trim();
        parts.add(other.isNotEmpty ? other : 'Other');
      } else {
        parts.add(w);
      }
    }
    return parts.join(', ');
  }

  
  Future<void> _hydrateFromServer() async {
    final id = (widget.story?['id'] as num?)?.toInt();
    if (id == null || id <= 0) return;
    try {
      // Prefer dedicated writer endpoint when available
      Map<String, dynamic>? data;
      try {
        data = await widget.apiService.fetchWriterStory(id);
      } catch (_) {
        data = null;
      }
      if (data == null) return;
      if (!mounted) return;
      setState(() {
        if ((data!['title'] ?? '').toString().isNotEmpty) {
          _titleController.text = data['title'].toString();
        }
        if (data['description'] != null) {
          _summaryController.text = data['description'].toString();
        }
        final genre = (data['genre'] ?? data['primary_genre'] ?? '').toString();
        if (genre.isNotEmpty) _selectedGenre = genre;
        final aud = (data['audience'] ?? '').toString();
        if (aud.isNotEmpty) _audience = aud;
        final lang = (data['language'] ?? '').toString();
        if (lang.isNotEmpty) _language = lang;
        final cover = (data['cover_path'] ?? '').toString();
        if (cover.isNotEmpty) _coverPath = cover;
        final tags = (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (tags.isNotEmpty) {
          _selectedTags
            ..clear()
            ..addAll(tags.take(3));
        }
        final warnings = (data['content_warnings'] ?? '').toString();
        if (warnings.isNotEmpty) {
          // best-effort: keep existing warning chips logic if any
        }
      });
    } catch (_) {}
  }

Future<void> _save({required bool asDraft}) async {
    final title = _titleController.text.trim();
    final summary = _summaryController.text.trim();
    final author = _authorController.text.trim();
    final genre = (_selectedGenre ?? '').trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final warnings = _buildWarningsString();
      // Create/meta screen always saves as Draft. Publish happens on chapter editor.
      final String statusText = 'Draft';
      final payload = <String, dynamic>{
        'title': title.isEmpty ? 'Untitled Story' : title,
        'description': summary,
        'author': author.isEmpty ? 'Author' : author,
        'genre': genre.isEmpty ? 'Romance' : genre,
        'content_warnings': warnings,
        'tags': List<String>.from(_selectedTags.take(3)),
        'status_text': statusText,
        'language': _language,
        'audience': (_audience ?? '').trim(),
        if (_coverPath.isNotEmpty) 'cover_path': _coverPath,
      };

      int storyId;
      if (_isEditing) {
        storyId = (widget.story!['id'] as num).toInt();
        await widget.apiService.updateWriterStory(storyId, payload);
      } else {
        storyId = await widget.apiService.createWriterStory(payload);
      }
      if (!mounted) return;
      if (!asDraft && storyId > 0) {
        // Nudge user to add a chapter (>= 50 words) so readers can see it.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _status == 'Completed'
                  ? 'Saved as Complete. Add a chapter with at least 50 words so others can read it.'
                  : 'Saved. Add at least one chapter (50+ words) to become an author.',
            ),
          ),
        );
      }
      if (storyId > 0) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EditChapterScreen(
              apiService: widget.apiService,
              storyId: storyId,
              createNew: true,
              chapterNumber: 1,
              chapterTitle: 'Chapter 1',
            ),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _tagSuggestions(String query) {
    final q = query.trim().toLowerCase().replaceFirst('#', '');
    final base = _availableTags
        .where((t) => !_selectedTags.any((s) => s.toLowerCase() == t.toLowerCase()))
        .toList();
    if (base.isEmpty) return const <String>[];
    if (q.isEmpty) return base.take(20).toList();
    final starts = base.where((t) => t.toLowerCase().startsWith(q)).toList();
    final contains = base
        .where((t) => !t.toLowerCase().startsWith(q) && t.toLowerCase().contains(q))
        .toList();
    return [...starts, ...contains].take(20).toList();
  }

  Future<void> _openPicker({
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String> onSelect,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: _textLo,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((opt) {
                    final selected = opt == current;
                    return ListTile(
                      title: Text(
                        opt,
                        style: TextStyle(
                          color: selected ? _magenta : _textHi,
                          fontSize: 15.5,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check, color: _magenta, size: 18)
                          : null,
                      onTap: () {
                        onSelect(opt);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _authorController.dispose();
    _tagInputController.dispose();
    _otherWarningController.dispose();
    _customGenreController.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleLen = _titleController.text.length;

    // Force light theme for the entire New Story / story creation page
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _ink,
        colorScheme: const ColorScheme.light(
          primary: _magenta,
          secondary: _violet,
          surface: _panel,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: _textHi),
          bodyMedium: TextStyle(color: _textLo),
          titleMedium: TextStyle(color: _textHi),
        ),
      ),
      child: Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF8F5),
                border: Border(bottom: BorderSide(color: _borderSoft)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      if (_titleController.text.trim().isNotEmpty && !_saving) {
                        try { await _save(asDraft: true); } catch (_) {}
                      }
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.arrow_back, color: _textHi),
                  ),
                  const Text(
                    'New Story',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _textHi,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : () => _save(asDraft: true),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: _magenta,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  GestureDetector(
                    onTap: _pickCover,
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _coverPath.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  widget.apiService.resolveAssetUrl(_coverPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(Icons.image_outlined, size: 40, color: _textLo),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Change',
                                      style: TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_rounded, size: 28, color: _textLo),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to upload a cover image',
                                  style: TextStyle(color: _textFaint, fontSize: 12),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Shown on Draft & Submitted lists',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: _textFaint),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('✒', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 8),
                            Text(
                              'DRAFT READINESS',
                              style: TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 0.8,
                                color: _textLo,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _readinessPct / 100,
                            minHeight: 7,
                            backgroundColor: _panelAlt,
                            valueColor: const AlwaysStoppedAnimation<Color>(_magenta),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _readinessCaption,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontStyle: FontStyle.italic,
                                  color: _textHi,
                                ),
                              ),
                            ),
                            Text(
                              '$_readinessPct%',
                              style: const TextStyle(
                                fontSize: 18,
                                color: _textHi,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('TITLE'),
                  const SizedBox(height: 7),
                  _darkField(
                    child: TextField(
                      controller: _titleController,
                      maxLength: 100,
                      style: const TextStyle(color: _textHi, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'My Story',
                        hintStyle: TextStyle(color: _textFaint),
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$titleLen / 100',
                      style: TextStyle(fontSize: 11, color: titleLen >= 100 ? _amber : _textFaint),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _label('AUTHOR (FROM YOUR ACCOUNT)'),
                  const SizedBox(height: 7),
                  Stack(
                    children: [
                      _darkField(
                        child: TextField(
                          controller: _authorController,
                          readOnly: true,
                          enabled: false,
                          style: const TextStyle(color: _textFaint, fontSize: 15),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 14,
                        top: 14,
                        child: Icon(Icons.lock, size: 14, color: _textFaint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _label('SUMMARY'),
                  const SizedBox(height: 7),
                  _darkField(
                    child: TextField(
                      controller: _summaryController,
                      maxLength: 500,
                      maxLines: 4,
                      style: const TextStyle(color: _textHi, fontSize: 15, height: 1.45),
                      decoration: const InputDecoration(
                        hintText: 'Short description of your story...',
                        hintStyle: TextStyle(color: _textFaint),
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_summaryController.text.length} / 500',
                      style: TextStyle(
                        fontSize: 11,
                        color: _summaryController.text.length >= 500 ? _amber : _textFaint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _label('GENRE'),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: _loadingGenres
                        ? null
                        : () => _openPicker(
                              title: 'Select genre',
                              options: _genres,
                              current: _selectedGenre,
                              onSelect: (v) => setState(() => _selectedGenre = v),
                            ),
                    child: _dropdownTrigger(
                      _selectedGenre ?? 'Select genre',
                      isPlaceholder: _selectedGenre == null,
                    ),
                  ),

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('LANGUAGE'),
                            const SizedBox(height: 7),
                            GestureDetector(
                              onTap: () => _openPicker(
                                title: 'Select language',
                                options: _languages,
                                current: _language,
                                onSelect: (v) => setState(() => _language = v),
                              ),
                              child: _dropdownTrigger(_language),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('AUDIENCE'),
                            const SizedBox(height: 7),
                            GestureDetector(
                              onTap: () => _openPicker(
                                title: 'Select audience',
                                options: _audiences,
                                current: _audience,
                                onSelect: (v) => setState(() => _audience = v),
                              ),
                              child: _dropdownTrigger(
                                _audience ?? 'Select audience',
                                isPlaceholder: _audience == null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _label('CONTENT WARNINGS (OPTIONAL)'),
                  const SizedBox(height: 7),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.2,
                    children: _warningOptions.map((w) {
                      final checked = _selectedWarnings.contains(w);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (checked) {
                              _selectedWarnings.remove(w);
                            } else {
                              _selectedWarnings.add(w);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                          decoration: BoxDecoration(
                            color: _panelAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: checked ? _magenta : _border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 15,
                                height: 15,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: checked ? Colors.transparent : _textFaint,
                                    width: 1.5,
                                  ),
                                  gradient: checked
                                      ? const LinearGradient(colors: [_magenta, _violet])
                                      : null,
                                ),
                                child: checked
                                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  w,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: checked ? _textHi : _textLo,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedWarnings.contains('Other')) ...[
                    const SizedBox(height: 8),
                    _darkField(
                      child: TextField(
                        controller: _otherWarningController,
                        style: const TextStyle(color: _textHi, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Describe the other warning...',
                          hintStyle: TextStyle(color: _textFaint),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _label('HASHTAGS (MAX 3)'),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _panelAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedTags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedTags.map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1A8B5CF6),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: const Color(0x668B5CF6)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '#$t',
                                        style: const TextStyle(color: Color(0xFF5B3FA6), fontSize: 12.5),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => _removeTag(t),
                                        child: const Icon(Icons.close, size: 12, color: Color(0xFF5B3FA6)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if (_selectedTags.length < 3)
                          RawAutocomplete<String>(
                            textEditingController: _tagInputController,
                            focusNode: _tagFocus,
                            optionsBuilder: (v) => _tagSuggestions(v.text),
                            onSelected: _addTag,
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                style: const TextStyle(color: _textHi, fontSize: 14.5),
                                decoration: const InputDecoration(
                                  hintText: 'Search admin hashtags…',
                                  hintStyle: TextStyle(color: _textFaint),
                                  prefixIcon: Icon(Icons.tag, size: 18, color: _textFaint),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: (v) {
                                  // Only accept if it matches a suggestion
                                  final opts = _tagSuggestions(v);
                                  if (opts.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Pick a hashtag from the suggestion list',
                                        ),
                                      ),
                                    );
                                  } else if (opts.any((o) =>
                                      o.toLowerCase() ==
                                      v.trim().toLowerCase().replaceFirst('#', ''))) {
                                    _addTag(v);
                                    onFieldSubmitted();
                                  } else {
                                    // Autofill closest
                                    _addTag(opts.first);
                                    onFieldSubmitted();
                                  }
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  color: _panel,
                                  elevation: 6,
                                  borderRadius: BorderRadius.circular(10),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        return ListTile(
                                          dense: true,
                                          title: Text('#$option', style: const TextStyle(color: _textHi)),
                                          onTap: () => onSelected(option),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        // Quick pick: show popular admin tags as chips
                        if (!_loadingTags &&
                            _availableTags.isNotEmpty &&
                            _selectedTags.length < 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _availableTags
                                  .where((t) => !_selectedTags
                                      .any((s) => s.toLowerCase() == t.toLowerCase()))
                                  .take(12)
                                  .map(
                                    (t) => ActionChip(
                                      label: Text('#$t', style: const TextStyle(fontSize: 12)),
                                      onPressed: () => _addTag(t),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        if (!_loadingTags && _availableTags.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'No admin hashtags yet. Ask an admin to create tags.',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        if (_loadingTags)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: LinearProgressIndicator(minHeight: 2, color: _magenta),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF8F5),
                border: Border(top: BorderSide(color: _borderSoft)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _save(asDraft: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textHi,
                        side: const BorderSide(color: _border),
                        backgroundColor: _panelAlt,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _textHi),
                            )
                          : const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : () => _save(asDraft: true), // meta → draft, then chapter editor
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _magenta,
                        disabledBackgroundColor: _magenta.withValues(alpha: 0.4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        letterSpacing: 0.9,
        color: _textLo,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _darkField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _dropdownTrigger(String text, {bool isPlaceholder = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isPlaceholder ? _textFaint : _textHi,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, color: _textLo, size: 20),
        ],
      ),
    );
  }

  Widget _segmentBtn(
    String label, {
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? _panel : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: active ? Border.all(color: _border) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? activeColor : _textLo,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
