import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/services/api_service.dart';
import '../../data/models/app_bootstrap.dart';
import 'story_detail_screen.dart';

/// Inkitt-style chapter reader: cover at start, mid-chapter ads,
/// Next Chapter ads, themes, reactions, native share, scroll-to-top.
class ChapterReaderScreen extends StatefulWidget {
  const ChapterReaderScreen({
    super.key,
    required this.apiService,
    required this.title,
    required this.author,
    required this.coverPath,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.chapterContent,
    this.bookId,
    this.tags = const [],
    this.authorUserId,
    this.authorPhotoUrl,
    this.chapters = const [],
    this.initialChapterIndex = 0,
    this.initialParagraphIndex = 0,
  });

  final ApiService apiService;
  final String title;
  final String author;
  final String coverPath;
  final int chapterNumber;
  final String chapterTitle;
  final String chapterContent;
  final int? bookId;
  final List<String> tags;
  final int? authorUserId;
  final String? authorPhotoUrl;
  final List<Map<String, dynamic>> chapters;
  final int initialChapterIndex;

  /// Resume position inside the chapter (0-based paragraph index).
  final int initialParagraphIndex;

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

enum _ReaderTheme { white, eggshell, nightowl }

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  int _readSeconds = 0;
  Timer? _readTimer;

  late int _chapterIndex;
  late List<Map<String, dynamic>> _chapters;
  late String _chapterTitle;
  late String _chapterContent;
  late int _chapterNumber;
  String? _authorPhotoUrl;
  int _lastParagraphIndex = 0;
  final Map<int, GlobalKey> _paragraphKeys = {};

  _ReaderTheme _theme = _ReaderTheme.white;
  double _fontSize = 17;
  bool _showThemePanel = false;
  final Set<String> _selectedReactions = {};
  final Map<String, int> _reactionCounts = {};
  bool _reactionsLoading = false;
  bool _liked = false;
  int _likeCount = 0;
  final ScrollController _scrollController = ScrollController();
  Map<int, int> _paragraphCommentCounts = {};

  static const _reactionOptions = <List<String>>[
    ['❤️', 'Love this'],
    ['😂', 'Funny'],
    ['🌶️', 'Spicy'],
    ['😨', 'Suspenseful'],
    ['😢', 'Emotional'],
    ['🤔', 'Profound'],
    ['🥰', 'Heartwarming'],
    ['😲', 'Shocking'],
    ['✍️', 'Good Writing'],
    ['📖', 'Compelling Plot'],
    ['🎭', 'Great Character'],
    ['💬', 'Strong Dialog'],
  ];

  @override
  void initState() {
    _readTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _readSeconds++);
    });

    super.initState();
    // Track as ongoing when reader opens
    unawaited(_markLibraryProgress(completed: false));
    _chapters = List<Map<String, dynamic>>.from(widget.chapters);
    _loadLikeState();
    _chapterIndex = widget.initialChapterIndex.clamp(
      0,
      _chapters.isEmpty ? 0 : _chapters.length - 1,
    );
    _lastParagraphIndex = widget.initialParagraphIndex;
    if (_chapters.isNotEmpty) {
      _applyChapter(_chapters[_chapterIndex], resumeParagraph: true);
    } else {
      _chapterTitle = widget.chapterTitle;
      _chapterContent = widget.chapterContent;
      _chapterNumber = widget.chapterNumber;
      _authorPhotoUrl = widget.authorPhotoUrl;
      _resolveAuthorPhoto();
    }
    _loadChaptersIfNeeded();
    _loadReactions();
    // Resume scroll to last paragraph after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToParagraph(_lastParagraphIndex);
    });
    // Extra retries after content/layout settles
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _scrollToParagraph(_lastParagraphIndex);
    });
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _scrollToParagraph(_lastParagraphIndex);
    });
    _scrollController.addListener(_updateVisibleParagraphFromScroll);
  }

  void _scrollToParagraph(int index) {
    if (index < 0) return;
    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      return;
    }
    var attempts = 0;
    void tryScroll() {
      if (!mounted) return;
      attempts++;
      final key = _paragraphKeys[index];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: attempts <= 2
              ? Duration.zero
              : const Duration(milliseconds: 400),
          alignment: 0.08,
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        // Estimate paragraph offset until keys exist
        final estimated = (index * 140.0).clamp(0.0, max);
        _scrollController.jumpTo(estimated);
      }
      if (attempts < 12) {
        Future<void>.delayed(Duration(milliseconds: 80 + attempts * 40), tryScroll);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
    Future<void>.delayed(const Duration(milliseconds: 200), tryScroll);
    Future<void>.delayed(const Duration(milliseconds: 500), tryScroll);
    Future<void>.delayed(const Duration(milliseconds: 900), tryScroll);
  }


  void _updateVisibleParagraphFromScroll() {
    if (!_scrollController.hasClients) return;
    final paras = _paragraphs();
    if (paras.isEmpty) return;
    // Prefer GlobalKey positions when available
    int best = _lastParagraphIndex;
    double bestDy = double.infinity;
    for (var i = 0; i < paras.length; i++) {
      final ctx = _paragraphKeys[i]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      // Closest paragraph near top third of screen
      final score = (y - 120).abs();
      if (score < bestDy) {
        bestDy = score;
        best = i;
      }
    }
    if (bestDy == double.infinity) {
      final offset = _scrollController.offset;
      best = (offset / 160).floor().clamp(0, paras.length - 1);
    }
    if (best != _lastParagraphIndex) {
      _lastParagraphIndex = best;
      unawaited(_markLibraryProgress(completed: false));
    }
  }

  Future<void> _persistReadTime() async {
    if (_readSeconds <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'reading_seconds_by_day_v1';
      final raw = prefs.getString(key) ?? '{}';
      final map = Map<String, dynamic>.from((jsonDecode(raw) as Map?) ?? {});
      final now = DateTime.now();
      // Monday=1 ... use weekday name
      final dayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final prev = (map[dayKey] as num?)?.toInt() ?? 0;
      map[dayKey] = prev + _readSeconds;
      // Keep last 60 days
      if (map.length > 60) {
        final keys = map.keys.map((k) => k.toString()).toList()..sort();
        for (final k in keys.take(map.length - 60)) {
          map.remove(k);
        }
      }
      await prefs.setString(key, jsonEncode(map));
    } catch (_) {}
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    unawaited(_persistReadTime());

    // Persist exact stop position as ongoing read (unless already completed)
    unawaited(_markLibraryProgress(completed: false));
    _scrollController.removeListener(_updateVisibleParagraphFromScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChaptersIfNeeded() async {
    if (_chapters.isNotEmpty || widget.bookId == null) return;
    try {
      final list = await widget.apiService.fetchStoryChapters(widget.bookId!);
      if (!mounted || list.isEmpty) return;
      setState(() {
        _chapters = list;
        // Prefer resume chapter from library (widget.chapterNumber)
        final idx = list.indexWhere(
          (c) => (c['chapter_number'] as num?)?.toInt() == widget.chapterNumber,
        );
        _chapterIndex = idx >= 0
            ? idx
            : (widget.initialChapterIndex < list.length
                ? widget.initialChapterIndex
                : 0);
        _applyChapter(_chapters[_chapterIndex], resumeParagraph: true);
      });
      // Restore paragraph after content paints
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lastParagraphIndex = widget.initialParagraphIndex;
        _scrollToParagraph(_lastParagraphIndex);
        unawaited(_markLibraryProgress(completed: false));
      });
    } catch (_) {}
  }

  void _applyChapter(Map<String, dynamic> chapter, {bool resumeParagraph = false}) {
    _chapterTitle = chapter['title'] as String? ?? 'Untitled';
    _chapterContent = chapter['content'] as String? ?? '';
    _chapterNumber =
        (chapter['chapter_number'] as num?)?.toInt() ?? (_chapterIndex + 1);
    _selectedReactions.clear();
    _reactionCounts.clear();
    _paragraphCommentCounts = {};
    _paragraphKeys.clear();
    if (!resumeParagraph) {
      // Navigating to a different chapter starts at top
      _lastParagraphIndex = 0;
    } else {
      _lastParagraphIndex = widget.initialParagraphIndex;
    }
    _loadReactions();
    unawaited(_loadParagraphCommentCounts());
  }

  Color get _bg {
    switch (_theme) {
      case _ReaderTheme.white:
        return Colors.white;
      case _ReaderTheme.eggshell:
        return const Color(0xFFF5F0E6);
      case _ReaderTheme.nightowl:
        return const Color(0xFF1A1A1A);
    }
  }

  Color get _fg =>
      _theme == _ReaderTheme.nightowl ? Colors.white : Colors.black87;

  Color get _muted =>
      _theme == _ReaderTheme.nightowl ? Colors.white60 : Colors.black54;

  Future<void> _resolveAuthorPhoto() async {
    if ((_authorPhotoUrl != null && _authorPhotoUrl!.isNotEmpty) ||
        widget.authorUserId == null) {
      return;
    }
    try {
      final profile = await widget.apiService.fetchProfile(
        widget.authorUserId!,
      );
      final photo = (profile['photo_url'] ?? profile['photoUrl'] ?? '')
          .toString();
      if (photo.isNotEmpty && mounted) {
        setState(() => _authorPhotoUrl = photo);
      }
    } catch (_) {}
  }


  BookDetailModel _storyDetailBook() {
    return BookDetailModel(
      id: widget.bookId ?? 0,
      title: widget.title,
      author: widget.author,
      description: '',
      statusText: '',
      rating: 0,
      genre: '',
      cta: 'Read now',
      coverPath: widget.coverPath,
      tags: widget.tags,
      authorUserId: widget.authorUserId,
    );
  }

  /// Back always returns to the story detail page (not a previous chapter).
  Future<void> _goBackToStoryDetail({bool completed = false}) async {
    await _persistReadTime();
    await _markLibraryProgress(completed: completed);
    if (!mounted) return;
    final id = widget.bookId;
    if (id != null && id > 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => StoryDetailScreen(
            apiService: widget.apiService,
            book: _storyDetailBook(),
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _goNext() async {
    if (_chapterIndex >= _chapters.length - 1) {
      // Finished last chapter → mark completed (drops from Ongoing) + story detail
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story completed')),
        );
      }
      await _goBackToStoryDetail(completed: true);
      return;
    }
    setState(() {
      _chapterIndex++;
      _lastParagraphIndex = 0;
      _applyChapter(_chapters[_chapterIndex]);
    });
    // Scroll to top of the new chapter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _openChapterList() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final coverUrl = widget.coverPath.isEmpty
            ? null
            : widget.apiService.resolveAssetUrl(widget.coverPath);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      if (coverUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            coverUrl,
                            width: 48,
                            height: 68,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.menu_book, size: 40),
                          ),
                        )
                      else
                        const Icon(Icons.menu_book, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'By ${widget.author}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final bookId = widget.bookId;
                          if (bookId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report submitted. Thank you.'),
                              ),
                            );
                            return;
                          }
                          try {
                            final res = await widget.apiService.reportBook(
                              bookId,
                            );
                            final flagged = res['flagged_for_admin'] == true;
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  flagged
                                      ? 'Report recorded. Story flagged for admin review (3+ reports).'
                                      : 'Report submitted. Thank you.',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not report: $e')),
                            );
                          }
                        },
                        child: const Text(
                          'Report Story',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _chapters.isEmpty ? 1 : _chapters.length,
                    itemBuilder: (context, index) {
                      if (_chapters.isEmpty) {
                        return ListTile(
                          title: Text(
                            'Chapter $_chapterNumber: $_chapterTitle',
                          ),
                          selected: true,
                        );
                      }
                      final c = _chapters[index];
                      final chapterNo =
                          (c['chapter_number'] as num?)?.toInt() ?? index + 1;
                      final title = c['title'] as String? ?? 'Untitled';
                      final selected = index == _chapterIndex;
                      return ListTile(
                        selected: selected,
                        selectedTileColor: const Color(0xFFF3F0FF),
                        title: Text(
                          'Chapter $chapterNo: $title',
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _chapterIndex = index;
                            _applyChapter(c);
                          });
                          Navigator.pop(ctx);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.jumpTo(0);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _share() async {
    final text =
        'Read "${widget.title}" by ${widget.author} — Chapter $_chapterNumber: $_chapterTitle\n'
        'Read free on our app.';
    try {
      await Share.share(text, subject: widget.title);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story link copied — share it anywhere')),
      );
    }
  }

  Future<void> _loadLikeState() async {
    final bookId = widget.bookId;
    if (bookId == null) return;
    try {
      final res = await widget.apiService.fetchBookLike(bookId);
      if (!mounted) return;
      setState(() {
        _liked = (res['liked'] as bool?) ?? false;
        _likeCount = (res['likes_count'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final bookId = widget.bookId;
    if (bookId == null) {
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
        if (_likeCount < 0) _likeCount = 0;
      });
      return;
    }
    try {
      final res = _liked
          ? await widget.apiService.unlikeBook(bookId)
          : await widget.apiService.likeBook(bookId);
      if (!mounted) return;
      setState(() {
        _liked = (res['liked'] as bool?) ?? !_liked;
        _likeCount = (res['likes_count'] as num?)?.toInt() ?? _likeCount;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final text =
          (msg.contains('401') ||
              msg.contains('token') ||
              msg.contains('unauthorized'))
          ? 'Sign in to like. One like per account.'
          : (msg.contains('timeout')
                ? 'Server busy — try like again'
                : 'Like failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Widget _buildAdBanner({required String label}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: _theme == _ReaderTheme.nightowl
            ? Colors.white10
            : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _theme == _ReaderTheme.nightowl
              ? Colors.white24
              : const Color(0xFFD0D7DE),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Advertisement',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sponsored content',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<String> _paragraphs() {
    final text = _chapterContent.trim();
    if (text.isEmpty) return const [];
    // Split on blank lines first; fall back to single newlines for denser text
    var parts = text.split(RegExp(r'\n\s*\n'));
    if (parts.length <= 1) {
      parts = text.split('\n');
    }
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }

  Future<void> _loadParagraphCommentCounts() async {
    final bookId = widget.bookId;
    if (bookId == null) return;
    try {
      final payload = await widget.apiService.fetchChapterCommentsPayload(
        bookId: bookId,
        chapterNumber: _chapterNumber,
      );
      final raw = payload['paragraph_counts'];
      final map = <int, int>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          final idx = int.tryParse('$k');
          final n = (v as num?)?.toInt() ?? 0;
          if (idx != null && n > 0) map[idx] = n;
        });
      }
      // Also count from items if counts missing
      final items = payload['items'];
      if (map.isEmpty && items is List) {
        for (final it in items) {
          if (it is! Map) continue;
          final pi = (it['paragraph_index'] as num?)?.toInt() ?? -1;
          if (pi >= 0) map[pi] = (map[pi] ?? 0) + 1;
        }
      }
      if (!mounted) return;
      setState(() => _paragraphCommentCounts = map);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _openParagraphComments(
    int paragraphIndex,
    String preview,
  ) async {
    final bookId = widget.bookId;
    if (bookId == null || bookId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open a published story to view comments'),
        ),
      );
      return;
    }
    var comments = <Map<String, dynamic>>[];
    var loading = true;
    var loadStarted = false;
    String? error;
    final controller = TextEditingController();
    var posting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            // Load once only — avoid re-fetch on every rebuild
            if (!loadStarted) {
              loadStarted = true;
              widget.apiService
                  .fetchChapterComments(
                    bookId: bookId,
                    chapterNumber: _chapterNumber,
                  )
                  .then((items) {
                    final filtered = items
                        .where(
                          (c) =>
                              ((c['paragraph_index'] as num?)?.toInt() ?? -1) ==
                              paragraphIndex,
                        )
                        .toList();
                    if (ctx.mounted) {
                      setModal(() {
                        comments = filtered;
                        loading = false;
                      });
                    }
                  })
                  .catchError((Object e) {
                    if (ctx.mounted) {
                      setModal(() {
                        loading = false;
                        error = 'Could not load comments';
                      });
                    }
                  });
            }
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Paragraph comments (${comments.length})',
                              style: TextStyle(
                                color: _fg,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: _muted),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    if (preview.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          preview.length > 120
                              ? '${preview.substring(0, 120)}…'
                              : preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    const Divider(),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : error != null
                          ? Center(
                              child: Text(
                                error!,
                                style: TextStyle(color: _muted),
                              ),
                            )
                          : comments.isEmpty
                          ? Center(
                              child: Text(
                                'No comments yet — be the first!',
                                style: TextStyle(color: _muted),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: comments.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final c = comments[i];
                                final name =
                                    '${c['display_name'] ?? c['username'] ?? 'Reader'}';
                                final body = '${c['body'] ?? ''}';
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: _fg,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            body,
                                            style: TextStyle(
                                              color: _fg,
                                              fontSize: 14,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                style: TextStyle(color: _fg),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) async {
                                  // same as send button
                                },
                                decoration: InputDecoration(
                                  hintText: 'Add a comment…',
                                  hintStyle: TextStyle(color: _muted),
                                  filled: true,
                                  fillColor: _theme == _ReaderTheme.nightowl
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFF2F2F2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: posting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send,
                                      color: Color(0xFF6C3CE1),
                                    ),
                              onPressed: posting
                                  ? null
                                  : () async {
                                      final text = controller.text.trim();
                                      if (text.isEmpty) return;
                                      setModal(() => posting = true);
                                      try {
                                        final item = await widget.apiService
                                            .postChapterComment(
                                              bookId: bookId,
                                              chapterNumber: _chapterNumber,
                                              body: text,
                                              paragraphIndex: paragraphIndex,
                                            );
                                        // Ensure UI has body/name even if API omits them
                                        final normalized = <String, dynamic>{
                                          'display_name':
                                              item['display_name'] ??
                                              item['username'] ??
                                              'You',
                                          'body': item['body'] ?? text,
                                          'paragraph_index':
                                              item['paragraph_index'] ??
                                              paragraphIndex,
                                          ...item,
                                        };
                                        controller.clear();
                                        setModal(() {
                                          comments = [normalized, ...comments];
                                          posting = false;
                                        });
                                        if (mounted) {
                                          setState(() {
                                            _paragraphCommentCounts[paragraphIndex] =
                                                (_paragraphCommentCounts[paragraphIndex] ??
                                                    0) +
                                                1;
                                          });
                                        }
                                      } catch (e) {
                                        setModal(() => posting = false);
                                        if (ctx.mounted) {
                                          final msg = e
                                              .toString()
                                              .toLowerCase();
                                          final friendly =
                                              msg.contains('401') ||
                                                  msg.contains(
                                                    'unauthorized',
                                                  ) ||
                                                  msg.contains('sign')
                                              ? 'Please sign in to comment'
                                              : msg.contains('timeout')
                                              ? 'Server busy — try again'
                                              : 'Could not post comment';
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(content: Text(friendly)),
                                          );
                                        }
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    Future.delayed(const Duration(milliseconds: 300), controller.dispose);
  }

  Widget _buildParagraphBlock(String text, int index) {
    final count = _paragraphCommentCounts[index] ?? 0;
    final key = _paragraphKeys.putIfAbsent(index, () => GlobalKey());
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _fg, fontSize: _fontSize, height: 1.75),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _openParagraphComments(index, text),
            child: Container(
              constraints: const BoxConstraints(minWidth: 28),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: count > 0 ? const Color(0xFFEDE9FE) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: count > 0
                        ? const Color(0xFF6C3CE1)
                        : _muted.withValues(alpha: 0.7),
                  ),
                  if (count > 0)
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6C3CE1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Split chapter content roughly in half for mid-chapter ad placement.
  // ignore: unused_element

  List<String> _contentParts() {
    final text = _chapterContent.trim();
    if (text.isEmpty) return ['', ''];
    final mid = text.length ~/ 2;
    final searchStart = (mid - 200).clamp(0, text.length);
    final searchEnd = (mid + 200).clamp(0, text.length);
    final window = text.substring(searchStart, searchEnd);
    final paraBreak = window.indexOf('\n\n');
    if (paraBreak >= 0) {
      final splitAt = searchStart + paraBreak;
      return [
        text.substring(0, splitAt).trim(),
        text.substring(splitAt).trim(),
      ];
    }
    final space = text.lastIndexOf(' ', mid);
    if (space > 0) {
      return [text.substring(0, space).trim(), text.substring(space).trim()];
    }
    return [text, ''];
  }

  @override
  Widget build(BuildContext context) {
    final total = _chapters.isEmpty ? 1 : _chapters.length;
    final pageLabel = '${_chapterIndex + 1}/$total';
    final hasNext =
        _chapters.isNotEmpty && _chapterIndex < _chapters.length - 1;
    final coverUrl = widget.coverPath.isEmpty
        ? null
        : widget.apiService.resolveAssetUrl(widget.coverPath);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_goBackToStoryDetail(completed: false));
      },
      child: Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
          // reading timer

        backgroundColor: _bg,
        foregroundColor: _fg,
        elevation: 0,
        centerTitle: true,
        title: Text(pageLabel, style: TextStyle(color: _muted, fontSize: 14)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _fg),
          onPressed: () => unawaited(_goBackToStoryDetail(completed: false)),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: _muted),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(widget.title),
                  content: Text(
                    'By ${widget.author}\n\nChapter $_chapterNumber: $_chapterTitle',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Chapter cover (book cover at start of every chapter)
                if (coverUrl != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        coverUrl,
                        width: 140,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 140,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.menu_book, size: 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Center(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _fg,
                      fontSize: _fontSize + 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage:
                            (_authorPhotoUrl != null &&
                                _authorPhotoUrl!.isNotEmpty)
                            ? NetworkImage(
                                widget.apiService.resolveAssetUrl(
                                  _authorPhotoUrl!,
                                ),
                              )
                            : null,
                        child:
                            (_authorPhotoUrl == null ||
                                _authorPhotoUrl!.isEmpty)
                            ? Text(
                                widget.author.isNotEmpty
                                    ? widget.author[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'By ${widget.author}',
                        style: TextStyle(
                          color: _muted,
                          fontSize: _fontSize - 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '〜〜〜〜〜〜〜〜',
                    style: TextStyle(color: _muted, letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _chapterTitle.toUpperCase().contains('CHAPTER') ||
                          _chapterTitle.toUpperCase().contains('PROLOGUE')
                      ? _chapterTitle
                      : 'CHAPTER $_chapterNumber: $_chapterTitle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _fg,
                    fontSize: _fontSize + 1,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                // Paragraphs with inline comment bubbles (Inkitt-style)
                if (_paragraphs().isEmpty)
                  Text(
                    'This chapter has not been written yet.',
                    style: TextStyle(
                      color: _fg,
                      fontSize: _fontSize,
                      height: 1.75,
                    ),
                  )
                else ...[
                  for (var i = 0; i < _paragraphs().length; i++) ...[
                    _buildParagraphBlock(_paragraphs()[i], i),
                    if (i == _paragraphs().length ~/ 2 &&
                        _paragraphs().length > 2)
                      _buildAdBanner(
                        label: 'Discover more stories you\'ll love',
                      ),
                  ],
                ],
                const SizedBox(height: 24),
                // Ad near Next Chapter button
                if (hasNext)
                  _buildAdBanner(label: 'Continue reading more free stories'),
                if (hasNext)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _goNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C3CE1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Next Chapter',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Let ${widget.author} know what you thought about this chapter!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Inkitt-style reaction grid (3 columns, compact)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _reactionOptions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (context, index) {
                    final opt = _reactionOptions[index];
                    final emoji = opt[0];
                    final label = opt[1];
                    final selected = _selectedReactions.contains(label);
                    return GestureDetector(
                      onTap: () => _toggleReaction(label),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFEDE9FE)
                                  : (_theme == _ReaderTheme.nightowl
                                        ? Colors.white12
                                        : const Color(0xFFF3F4F6)),
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: const Color(0xFF6C3CE1),
                                      width: 2,
                                    )
                                  : Border.all(
                                      color: _theme == _ReaderTheme.nightowl
                                          ? Colors.white24
                                          : const Color(0xFFE5E7EB),
                                    ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF6C3CE1)
                                  : _muted,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          if ((_reactionCounts[label] ?? 0) > 0)
                            Text(
                              '${_reactionCounts[label]}',
                              style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? const Color(0xFF6C3CE1)
                                    : _muted,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                if (_selectedReactions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${_selectedReactions.length} reaction${_selectedReactions.length == 1 ? '' : 's'} selected',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_showThemePanel) _buildThemePanel(),
          _buildBottomBar(),
        ],
      ),
    ));
  }

  Widget _buildThemePanel() {
    return Material(
      color: _bg,
      elevation: 8,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          color: _bg,
          border: Border(
            top: BorderSide(color: _muted.withValues(alpha: 0.25)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reading theme',
                  style: TextStyle(
                    color: _fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 20, color: _muted),
                  onPressed: () => setState(() => _showThemePanel = false),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _themeChip(
                  'White',
                  _ReaderTheme.white,
                  Colors.white,
                  Colors.black,
                ),
                _themeChip(
                  'Eggshell',
                  _ReaderTheme.eggshell,
                  const Color(0xFFF5F0E6),
                  Colors.black87,
                ),
                _themeChip(
                  'Nightowl',
                  _ReaderTheme.nightowl,
                  const Color(0xFF1A1A1A),
                  Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Font size  ${_fontSize.round()}',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _fontSize = (_fontSize - 1).clamp(14.0, 28.0);
                    });
                  },
                  child: Text('A−', style: TextStyle(color: _fg, fontSize: 14)),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF6C3CE1),
                      thumbColor: const Color(0xFF6C3CE1),
                      overlayColor: const Color(0x336C3CE1),
                    ),
                    child: Slider(
                      value: _fontSize.clamp(14.0, 28.0),
                      min: 14,
                      max: 28,
                      divisions: 14,
                      label: '${_fontSize.round()}',
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                      },
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _fontSize = (_fontSize + 1).clamp(14.0, 28.0);
                    });
                  },
                  child: Text('A+', style: TextStyle(color: _fg, fontSize: 18)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeChip(String label, _ReaderTheme value, Color bg, Color fg) {
    final selected = _theme == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _theme = value;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF6C3CE1)
                      : Colors.grey.shade400,
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF6C3CE1,
                          ).withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Aa',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF6C3CE1) : _muted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  Future<void> _loadReactions() async {
    final bookId = widget.bookId;
    if (bookId == null) return;
    setState(() => _reactionsLoading = true);
    try {
      final data = await widget.apiService.fetchChapterReactions(
        bookId: bookId,
        chapterNumber: _chapterNumber,
      );
      final countsRaw = data['counts'];
      final mineRaw = data['mine'];
      final counts = <String, int>{};
      if (countsRaw is Map) {
        countsRaw.forEach((k, v) {
          counts[k.toString()] = int.tryParse(v.toString()) ?? 0;
        });
      }
      final mine = <String>{};
      if (mineRaw is List) {
        for (final e in mineRaw) {
          mine.add(e.toString());
        }
      }
      if (!mounted) return;
      setState(() {
        _reactionCounts
          ..clear()
          ..addAll(counts);
        _selectedReactions
          ..clear()
          ..addAll(mine);
        _reactionsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _reactionsLoading = false);
    }
  }

  Future<void> _toggleReaction(String label) async {
    final bookId = widget.bookId;
    if (bookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to react to chapters')),
      );
      return;
    }
    // Optimistic UI
    final wasSelected = _selectedReactions.contains(label);
    setState(() {
      if (wasSelected) {
        _selectedReactions.remove(label);
        _reactionCounts[label] = ((_reactionCounts[label] ?? 1) - 1).clamp(
          0,
          999999,
        );
      } else {
        _selectedReactions.add(label);
        _reactionCounts[label] = (_reactionCounts[label] ?? 0) + 1;
      }
    });
    try {
      final res = await widget.apiService.toggleChapterReaction(
        bookId: bookId,
        chapterNumber: _chapterNumber,
        label: label,
      );
      if (!mounted) return;
      final selected = res['selected'] == true;
      final count = int.tryParse('${res['count'] ?? 0}') ?? 0;
      setState(() {
        if (selected) {
          _selectedReactions.add(label);
        } else {
          _selectedReactions.remove(label);
        }
        _reactionCounts[label] = count;
      });
    } catch (e) {
      // roll back
      if (!mounted) return;
      setState(() {
        if (wasSelected) {
          _selectedReactions.add(label);
          _reactionCounts[label] = (_reactionCounts[label] ?? 0) + 1;
        } else {
          _selectedReactions.remove(label);
          _reactionCounts[label] = ((_reactionCounts[label] ?? 1) - 1).clamp(
            0,
            999999,
          );
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save reaction: $e')));
    }
  }

  Future<void> _openCommentsSheet() async {
    final bookId = widget.bookId;
    if (bookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open a published story to view comments'),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    var comments = <Map<String, dynamic>>[];
    var loading = true;
    var posting = false;
    String? error;

    Future<void> loadComments(void Function(void Function()) setModal) async {
      setModal(() {
        loading = true;
        error = null;
      });
      try {
        final items = await widget.apiService.fetchChapterComments(
          bookId: bookId,
          chapterNumber: _chapterNumber,
        );
        setModal(() {
          comments = items;
          loading = false;
        });
      } catch (e) {
        setModal(() {
          loading = false;
          error = 'Could not load comments';
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var startedLoad = false;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            if (!startedLoad) {
              startedLoad = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                loadComments(setModal);
              });
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.65,
                maxChildSize: 0.92,
                minChildSize: 0.4,
                builder: (_, scrollCtrl) {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                loading
                                    ? 'Comments'
                                    : 'Comments (${comments.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: posting
                                  ? null
                                  : () => loadComments(setModal),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : error != null
                            ? Center(
                                child: Text(
                                  error!,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : comments.isEmpty
                            ? Center(
                                child: Text(
                                  'No comments yet — be the first!',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  12,
                                ),
                                itemCount: comments.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (_, i) {
                                  final c = comments[i];
                                  final name =
                                      (c['display_name'] ??
                                              c['username'] ??
                                              'Reader')
                                          .toString();
                                  final body = (c['body'] ?? '').toString();
                                  final when = _relativeTime(
                                    (c['created_at'] ?? '').toString(),
                                  );
                                  final photo = (c['photo_url'] ?? '')
                                      .toString();
                                  final letter = name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : 'R';
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(
                                          0xFFE8EEF9,
                                        ),
                                        backgroundImage: photo.isNotEmpty
                                            ? NetworkImage(
                                                widget.apiService
                                                    .resolveAssetUrl(photo),
                                              )
                                            : null,
                                        child: photo.isEmpty
                                            ? Text(
                                                letter,
                                                style: const TextStyle(
                                                  color: Color(0xFF6C3CE1),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (when.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    when,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              body,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                enabled: !posting,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment…',
                                  filled: true,
                                  fillColor: const Color(0xFFF3F4F6),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: posting
                                    ? null
                                    : (_) async {
                                        // handled by send button path below
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: posting
                                  ? null
                                  : () async {
                                      final text = controller.text.trim();
                                      if (text.isEmpty) return;
                                      setModal(() => posting = true);
                                      try {
                                        final item = await widget.apiService
                                            .postChapterComment(
                                              bookId: bookId,
                                              chapterNumber: _chapterNumber,
                                              body: text,
                                            );
                                        controller.clear();
                                        setModal(() {
                                          comments = [item, ...comments];
                                          posting = false;
                                        });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Comment posted'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModal(() => posting = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e
                                                        .toString()
                                                        .toLowerCase()
                                                        .contains('timeout')
                                                    ? 'Server busy — post again in a moment'
                                                    : 'Could not post: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: posting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                      color: Color(0xFF6C3CE1),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: _bg,
          border: Border(top: BorderSide(color: _muted.withValues(alpha: 0.2))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _barItem(
              icon: Icons.text_fields,
              label: 'Theme',
              onTap: () => setState(() => _showThemePanel = !_showThemePanel),
            ),
            _barItem(
              icon: _liked ? Icons.favorite : Icons.favorite_border,
              label: _likeCount > 0 ? '$_likeCount Likes' : 'Like',
              color: _liked ? Colors.red : null,
              onTap: _toggleLike,
            ),
            _barItem(
              icon: Icons.chat_bubble_outline,
              label: 'Comments',
              onTap: _openCommentsSheet,
            ),
            _barItem(icon: Icons.ios_share, label: 'Share', onTap: _share),
            _barItem(
              icon: Icons.menu,
              label: 'Chapter',
              onTap: _openChapterList,
            ),
          ],
        ),
      ),
    );
  }

  Widget _barItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color ?? _muted),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color ?? _muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
