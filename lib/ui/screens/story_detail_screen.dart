import 'dart:async';
import 'package:flutter/material.dart';

import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'profile_screen.dart';
import 'chapter_reader_screen.dart';

/// Story detail page modeled after the Inkitt video:
/// centered cover, title, stats (Chapters / Last Updated / Reviews),
/// summary + Read More, Likes / Save / Reviews row, genres, tags,
/// author + Follow, chapter list, sticky green Read Now.
class StoryDetailScreen extends StatefulWidget {
  const StoryDetailScreen({
    super.key,
    required this.book,
    required this.apiService,
  });

  final BookDetailModel book;
  final ApiService apiService;

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late BookDetailModel _book;
  bool _isFollowing = false;
  bool _loadingFollow = false;
  bool _loadingChapters = true;
  bool _summaryExpanded = false;
  List<Map<String, dynamic>> _chapters = const [];
  List<String> _tags = const [];
  List<Map<String, dynamic>> _reviews = const [];
  bool _loadingReviews = true;
  int _viewCount = 0;
  String? _error;
  int _likesCount = 0;
  bool _liked = false;
  bool _likeBusy = false;
  bool _saved = false;
  bool _hasMyReview = false;
  int? _currentUserId;

  bool get _isOwner {
    final aid = _book.authorUserId;
    final me = _currentUserId;
    return aid != null && me != null && aid == me;
  }
  List<Map<String, dynamic>> _authorStories = const [];
  List<Map<String, dynamic>> _youMayAlsoLike = const [];
  String? _authorPhotoUrl;
  String _contentWarningsExtra = '';

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _tags = List<String>.from(widget.book.tags);
    _viewCount = widget.book.viewCount;
    _bootstrap();
    unawaited(_checkSavedAndReviewed());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingChapters = true;
      _error = null;
    });
    try {
      final detail = await widget.apiService.fetchPublicBook(_book.id);
      if (detail != null && mounted) {
        setState(() {
          _book = BookDetailModel.fromMap(detail);
          _tags = List<String>.from(_book.tags);
          _likesCount =
              (detail['likes_count'] as num?)?.toInt() ??
              (detail['likes'] as num?)?.toInt() ??
              0;
          _viewCount =
              (detail['view_count'] as num?)?.toInt() ??
              (detail['views'] as num?)?.toInt() ??
              _viewCount;
          final photo =
              (detail['author_photo_url'] ??
                      detail['author_photo'] ??
                      detail['photo_url'] ??
                      detail['authorPhotoUrl'] ??
                      '')
                  .toString();
          if (photo.isNotEmpty) {
            _authorPhotoUrl = photo;
          }
          final cw =
              (detail['content_warnings'] ??
                      detail['content_warning'] ??
                      detail['contentWarnings'] ??
                      '')
                  .toString()
                  .trim();
          if (cw.isNotEmpty) {
            _contentWarningsExtra = cw;
          }
        });
      }
      final chapters = await widget.apiService.fetchStoryChapters(_book.id);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loadingChapters = false;
      });
      final aid = _book.authorUserId;
      if (aid != null) {
        try {
          final following = await widget.apiService.fetchAuthorFollowing(aid);
          if (mounted) setState(() => _isFollowing = following);
        } catch (_) {}
        try {
          final others = await widget.apiService.fetchAuthorBooks(
            aid,
            excludeBookId: _book.id,
          );
          if (mounted) setState(() => _authorStories = others);
        } catch (_) {}
        // Resolve author profile photo for reader header + detail avatar
        if (_authorPhotoUrl == null || _authorPhotoUrl!.isEmpty) {
          try {
            final profile = await widget.apiService.fetchProfile(aid);
            final photo =
                (profile['photo_url'] ??
                        profile['photoUrl'] ??
                        profile['avatar_url'] ??
                        '')
                    .toString();
            if (photo.isNotEmpty && mounted) {
              setState(() => _authorPhotoUrl = photo);
            }
          } catch (_) {}
        }
      }
      final reviews = await widget.apiService.fetchBookReviews(_book.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loadingReviews = false;
        });
      }

      try {
        final likeState = await widget.apiService.fetchBookLike(_book.id);
        if (mounted) {
          setState(() {
            _liked = (likeState['liked'] as bool?) ?? false;
            final c = (likeState['likes_count'] as num?)?.toInt();
            if (c != null) _likesCount = c;
          });
        }
      } catch (_) {}
      // More Stories by Author + You May Also Like (loaded above via aid)
      // Related by first tag or genre
      try {
        List<Map<String, dynamic>> related = [];
        if (_tags.isNotEmpty) {
          related = await widget.apiService.fetchBooksByTag(_tags.first);
        }
        if (related.isEmpty && _book.genre.isNotEmpty) {
          // fallback: search by genre via bootstrap-style or tag
          related = await widget.apiService.fetchBooksByTag(_book.genre);
        }
        related = related
            .where((b) => (b['id'] as num?)?.toInt() != _book.id)
            .take(12)
            .toList();
        if (mounted) setState(() => _youMayAlsoLike = related);
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingChapters = false;
          _loadingReviews = false;
          _error = 'Unable to load story details.';
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final aid = _book.authorUserId;
    if (aid == null || _loadingFollow) return;
    if (_isOwner) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot follow yourself')),
        );
      }
      return;
    }
    setState(() => _loadingFollow = true);
    try {
      late final Map<String, dynamic> result;
      if (_isFollowing) {
        result = await widget.apiService.unfollowAuthor(aid);
      } else {
        result = await widget.apiService.followAuthor(aid);
      }
      if (!mounted) return;
      if (result['self'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot follow yourself')),
        );
        return;
      }
      setState(() => _isFollowing = result['following'] == true);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().toLowerCase();
        final text = (msg.contains('timeout') || msg.contains('timed out'))
            ? 'Server busy — tap Follow again in a moment'
            : (msg.contains('401') ||
                  msg.contains('unauthorized') ||
                  msg.contains('sign'))
            ? 'Please sign in to follow authors'
            : 'Could not update follow — try again';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      }
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  Future<void> _checkSavedAndReviewed() async {
    try {
      final me = await widget.apiService.fetchMe();
      final uid = (me['id'] as num?)?.toInt() ??
          (me['user_id'] as num?)?.toInt();
      if (mounted && uid != null) setState(() => _currentUserId = uid);
    } catch (_) {}
    try {
      final lib = await widget.apiService.fetchLibraryEntries();
      final saved = lib.any((e) {
        final bid = (e['book_id'] as num?)?.toInt() ??
            ((e['book'] as Map?)?['id'] as num?)?.toInt() ??
            0;
        return bid == _book.id;
      });
      if (mounted) setState(() => _saved = saved);
    } catch (_) {}
    try {
      final reviews = await widget.apiService.fetchBookReviews(_book.id);
      // If current user review exists API may mark mine; else after post we set
      final mine = reviews.any((r) => r['is_mine'] == true || r['mine'] == true);
      if (mounted && mine) setState(() => _hasMyReview = true);
    } catch (_) {}
  }

  Future<void> _openReadingListPicker() async {
    if (_isOwner) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot save your own story')),
        );
      }
      return;
    }
    try {
      var lists = await widget.apiService.fetchReadingLists();
      if (!mounted) return;
      final choice = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text(
                    'Save to reading list',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create new list'),
                  onTap: () =>
                      Navigator.pop(ctx, <String, dynamic>{'_create': true}),
                ),
                if (lists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No lists yet — create one above.'),
                  ),
                ...lists.map((list) {
                  final name = list['name'] as String? ?? 'List';
                  return ListTile(
                    leading: const Icon(Icons.playlist_add_check),
                    title: Text(name),
                    onTap: () => Navigator.pop(ctx, list),
                  );
                }),
              ],
            ),
          );
        },
      );
      if (choice == null) return;

      if (choice['_create'] == true) {
        final nameCtrl = TextEditingController();
        final name = await showDialog<String>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Create reading list'),
            content: TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'List name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dCtx, nameCtrl.text.trim()),
                child: const Text('Create'),
              ),
            ],
          ),
        );
        if (name == null || name.isEmpty) return;
        final created = await widget.apiService.createReadingList({
          'name': name,
          'story_count': 0,
          'cover_path': '',
          'sort_order': lists.length + 1,
        });
        var newId = (created['id'] as num?)?.toInt() ?? 0;
        if (newId == 0) {
          lists = await widget.apiService.fetchReadingLists();
          for (final l in lists) {
            if ((l['name'] as String?) == name) {
              newId = (l['id'] as num?)?.toInt() ?? 0;
              break;
            }
          }
        }
        if (newId != 0) {
          await widget.apiService.addReadingListItem(newId, _book.id);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newId != 0
                  ? 'Created "$name" and saved this story'
                  : 'Created "$name". Open Library to confirm.',
            ),
          ),
        );
        if (mounted) setState(() => _saved = true);
        return;
      }

      final listId = (choice['id'] as num?)?.toInt() ?? 0;
      if (listId == 0) return;
      await widget.apiService.addReadingListItem(listId, _book.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${choice['name'] ?? 'reading list'}')),
      );
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('401') || e.toString().contains('403')
                ? 'Please sign in to use reading lists'
                : 'Could not save to reading list',
          ),
        ),
      );
    }
  }

  Future<void> _trackReadingInLibrary({bool completed = false}) async {
    try {
      await widget.apiService.addLibraryEntry({
        'book_id': _book.id,
        'reading_status': completed ? 'Completed' : 'Reading',
        'updated_text': completed ? 'Finished' : 'Reading',
        'chapters': _chapters.length,
        'primary_genre': _book.genre,
        'secondary_genre': '',
        'sort_order': 0,
      });
    } catch (_) {
      // ignore if not signed in
    }
  }

  void _openChapter(Map<String, dynamic> chapter, {int? index}) {
    final chapterTitle = chapter['title'] as String? ?? 'Untitled chapter';
    final chapterNumber = (chapter['chapter_number'] as num?)?.toInt() ?? 1;
    final chapterContent = chapter['content'] as String? ?? '';
    final idx =
        index ??
        _chapters.indexWhere(
          (c) =>
              identical(c, chapter) ||
              ((c['chapter_number'] as num?)?.toInt() == chapterNumber &&
                  (c['title'] as String?) == chapterTitle),
        );
    // Always track as Ongoing when a chapter is opened
    unawaited(_trackReadingInLibrary(completed: false));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderScreen(
          apiService: widget.apiService,
          title: _book.title,
          author: _book.author,
          coverPath: _book.coverPath,
          chapterNumber: chapterNumber,
          chapterTitle: chapterTitle,
          chapterContent: chapterContent,
          bookId: _book.id,
          tags: _tags,
          authorUserId: _book.authorUserId,
          authorPhotoUrl: _authorPhotoUrl,
          chapters: _chapters,
          initialChapterIndex: idx < 0 ? 0 : idx,
        ),
      ),
    );
  }

  Future<void> _readNow() async {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chapters available yet')),
      );
      return;
    }
    await _trackReadingInLibrary(completed: false);
    if (!mounted) return;
    _openChapter(_chapters.first);
  }

  Future<void> _openTag(String tag) async {
    final books = await widget.apiService.fetchBooksByTag(tag);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TagBooksScreen(
          tag: tag,
          books: books,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  Widget _statCell(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = _book.coverPath.isEmpty
        ? null
        : widget.apiService.resolveAssetUrl(_book.coverPath);
    final summary = _book.description.isEmpty
        ? 'No summary available.'
        : _book.description;
    final needsExpand = summary.length > 160;

    if (_loadingChapters) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading story...'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Colors.black87,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () {
                  // System share is handled on reader; here just open reading list as secondary
                  _openReadingListPicker();
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () async {
                  final action = await showMenu<String>(
                    context: context,
                    position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
                    items: const [
                      PopupMenuItem(
                        value: 'list',
                        child: Text('Save to reading list'),
                      ),
                      PopupMenuItem(
                        value: 'review',
                        child: Text('Write a review'),
                      ),
                      PopupMenuItem(
                        value: 'report',
                        child: Text('Report story'),
                      ),
                    ],
                  );
                  if (action == 'list') {
                    await _openReadingListPicker();
                  } else if (action == 'review') {
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _WriteReviewScreen(
                          bookId: _book.id,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                    final reviews = await widget.apiService.fetchBookReviews(
                      _book.id,
                    );
                    if (mounted) setState(() => _reviews = reviews);
                  } else if (action == 'report') {
                    try {
                      final res = await widget.apiService.reportBook(_book.id);
                      if (!mounted) return;
                      final flagged = res['flagged_for_admin'] == true;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            flagged
                                ? 'Report recorded. Story flagged for admin (3+ reports).'
                                : 'Report submitted. Thank you.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not report: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ),

          // Centered cover (matches video)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: coverUrl == null
                      ? Container(
                          width: 160,
                          height: 230,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.menu_book, size: 48),
                        )
                      : Image.network(
                          coverUrl,
                          width: 160,
                          height: 230,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 160,
                            height: 230,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Title centered
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Text(
                    _book.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  if (_book.author.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'by ${_book.author}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Stats row: Chapters | Last Updated | Reviews
          if (!_loadingChapters)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statCell('Chapters', '${_chapters.length}'),
                    _statCell(
                      _book.lastUpdated.trim().isNotEmpty
                          ? 'Last Updated'
                          : 'Story Status',
                      _book.lastUpdated.trim().isNotEmpty
                          ? _book.lastUpdated.trim()
                          : (_book.statusText.isNotEmpty
                                ? _book.statusText
                                : 'Ongoing'),
                    ),
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_viewCount',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Views',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                    _statCell(
                      'Reviews',
                      _book.rating > 0
                          ? '★ ${_book.rating.toStringAsFixed(1)}'
                          : '${_reviews.length}',
                    ),
                  ],
                ),
              ),
            ),

          // Summary + Read More
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    maxLines: _summaryExpanded || !needsExpand ? null : 4,
                    overflow: _summaryExpanded || !needsExpand
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: const Color(0xFF444444),
                    ),
                  ),
                  if (needsExpand)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(
                          () => _summaryExpanded = !_summaryExpanded,
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          minimumSize: const Size(48, 40),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          foregroundColor: const Color(0xFF00C853),
                        ),
                        child: Text(
                          _summaryExpanded ? 'Show less' : 'Read More',
                          style: const TextStyle(
                            color: Color(0xFF00C853),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Likes | Save | Reviews row (video)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: (_likeBusy || _isOwner)
                        ? null
                        : () async {
                            setState(() => _likeBusy = true);
                            try {
                              final res = _liked
                                  ? await widget.apiService.unlikeBook(_book.id)
                                  : await widget.apiService.likeBook(_book.id);
                              if (!mounted) return;
                              setState(() {
                                if (res['self'] == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'You cannot like your own story',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                _liked = (res['liked'] as bool?) ?? !_liked;
                                _likesCount =
                                    (res['likes_count'] as num?)?.toInt() ??
                                    _likesCount;
                              });
                            } catch (e) {
                              if (!mounted) return;
                              final msg = e.toString();
                              final lower = msg.toLowerCase();
                              String text;
                              if (lower.contains('401') ||
                                  lower.contains('missing user token') ||
                                  lower.contains('unauthorized') ||
                                  lower.contains('sign in')) {
                                text = 'Sign in to like stories';
                              } else if (lower.contains('timeout')) {
                                text =
                                    'Server busy — try like again in a moment';
                              } else {
                                text =
                                    'Could not update like: ${msg.length > 80 ? msg.substring(0, 80) : msg}';
                              }
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(text)));
                            } finally {
                              if (mounted) setState(() => _likeBusy = false);
                            }
                          },
                    icon: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: _isOwner
                          ? Colors.black26
                          : (_liked ? Colors.red : null),
                    ),
                    label: Text(
                      _likesCount > 0 ? '$_likesCount Likes' : 'Likes',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          _isOwner ? Colors.black26 : Colors.black87,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isOwner
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You cannot save your own story',
                                ),
                              ),
                            );
                          }
                        : _openReadingListPicker,
                    icon: Icon(
                      _saved ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: _isOwner
                          ? Colors.black26
                          : (_saved ? const Color(0xFF1A73E8) : null),
                    ),
                    label: Text(_saved ? 'Saved' : 'Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: _isOwner
                          ? Colors.black26
                          : (_saved
                              ? const Color(0xFF1A73E8)
                              : Colors.black87),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isOwner
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You cannot review your own story',
                                ),
                              ),
                            );
                          }
                        : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _BookReviewsPage(
                                  book: _book,
                                  apiService: widget.apiService,
                                  isOwner: _isOwner,
                                  hasMyReview: _hasMyReview,
                                  onReviewPosted: () async {
                                    setState(() => _hasMyReview = true);
                                    final reviews = await widget.apiService
                                        .fetchBookReviews(_book.id);
                                    if (mounted) {
                                      setState(() => _reviews = reviews);
                                    }
                                  },
                                ),
                              ),
                            );
                            final reviews =
                                await widget.apiService.fetchBookReviews(
                              _book.id,
                            );
                            if (mounted) setState(() => _reviews = reviews);
                          },
                    icon: Icon(
                      _hasMyReview ? Icons.star : Icons.star_border,
                      size: 20,
                      color: _isOwner
                          ? Colors.black26
                          : (_hasMyReview ? const Color(0xFFFFC107) : null),
                    ),
                    label: Text(
                      _reviews.isEmpty
                          ? 'Reviews'
                          : '${_reviews.length} Reviews',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _isOwner
                          ? Colors.black26
                          : (_hasMyReview
                              ? const Color(0xFFF9A825)
                              : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Warnings (video: show when present on book)
          if (_book.contentWarnings.trim().isNotEmpty ||
              _contentWarningsExtra.trim().isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Content Warnings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      () {
                        final w = _book.contentWarnings.trim().isNotEmpty
                            ? _book.contentWarnings.trim()
                            : _contentWarningsExtra.trim();
                        if (w.toLowerCase().startsWith('this story')) return w;
                        return 'This story contains themes of: $w';
                      }(),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Genres — chips keep hierarchical "Parent > Child" when present
          if (_book.genre.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Genres',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: () {
                          final raw = _book.genre.trim();
                          final parts = raw
                              .split(RegExp(r'[,|]'))
                              .map((g) => g.trim())
                              .where((g) => g.isNotEmpty)
                              .toList();
                          return [
                            for (final g in parts)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    g,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                          ];
                        }(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Tags / hashtags (clickable)
          if (_tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tags',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final t in _tags)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(
                                  t.startsWith('#')
                                      ? t.replaceFirst('#', '')
                                      : t,
                                ),
                                onPressed: () => _openTag(t),
                                backgroundColor: const Color(0xFFD4F5E9),
                                side: BorderSide.none,
                                labelStyle: const TextStyle(
                                  color: Color(0xFF0A7A4B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Author + Follow (avatar/name tappable → profile; solid green Follow)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Author',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final aid = _book.authorUserId;
                          if (aid == null || aid <= 0) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProfileScreen(
                                apiService: widget.apiService,
                                viewingUserId: aid,
                                achievements: const [],
                                profile: ProfileModel(
                                  id: aid,
                                  displayName: _book.author.isNotEmpty
                                      ? _book.author
                                      : 'Author',
                                  username: _book.author
                                      .toLowerCase()
                                      .replaceAll(' ', ''),
                                  photoUrl: _authorPhotoUrl ?? '',
                                  coverUrl: '',
                                  following: 0,
                                  followers: 0,
                                  blocked: 0,
                                  chaptersRead: 0,
                                  socialKarma: 0,
                                  dayStreak: 0,
                                  readingLists: const [],
                                ),
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 22,
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
                                  _book.author.isNotEmpty
                                      ? _book.author[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final aid = _book.authorUserId;
                            if (aid == null || aid <= 0) return;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProfileScreen(
                                  apiService: widget.apiService,
                                  viewingUserId: aid,
                                  achievements: const [],
                                  profile: ProfileModel(
                                    id: aid,
                                    displayName: _book.author.isNotEmpty
                                        ? _book.author
                                        : 'Author',
                                    username: _book.author
                                        .toLowerCase()
                                        .replaceAll(' ', ''),
                                    photoUrl: _authorPhotoUrl ?? '',
                                    coverUrl: '',
                                    following: 0,
                                    followers: 0,
                                    blocked: 0,
                                    chaptersRead: 0,
                                    socialKarma: 0,
                                    dayStreak: 0,
                                    readingLists: const [],
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            _book.author.isEmpty
                                ? 'Unknown author'
                                : _book.author,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      if (_book.authorUserId != null && !_isOwner)
                        SizedBox(
                          height: 36,
                          child: _isFollowing
                              ? OutlinedButton(
                                  onPressed: _loadingFollow
                                      ? null
                                      : _toggleFollow,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.grey.shade400,
                                    ),
                                    foregroundColor: Colors.black54,
                                    backgroundColor: Colors.grey.shade100,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text(
                                    'Following',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _loadingFollow
                                      ? null
                                      : _toggleFollow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00C853),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                  ),
                                  child: const Text(
                                    'Follow',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Reviews section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Reviews',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _WriteReviewScreen(
                            bookId: _book.id,
                            apiService: widget.apiService,
                          ),
                        ),
                      );
                      final reviews = await widget.apiService.fetchBookReviews(
                        _book.id,
                      );
                      if (mounted) setState(() => _reviews = reviews);
                    },
                    child: const Text('Write'),
                  ),
                ],
              ),
            ),
          ),
          // Reviews only on Reviews page (button above)

          // Chapters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Chapters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_loadingChapters)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_chapters.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No chapters published yet.'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final chapter = _chapters[index];
                final rawTitle = (chapter['title'] as String? ?? '').trim();
                final number =
                    (chapter['chapter_number'] as num?)?.toInt() ?? index + 1;
                // Inkitt-style: "Chapter N  Title" (muted green)
                final lower = rawTitle.toLowerCase().trim();
                String secondary;
                if (rawTitle.isEmpty ||
                    RegExp(r'^chapter\s*\d+$').hasMatch(lower)) {
                  secondary = 'Chapter $number';
                } else {
                  secondary = rawTitle;
                }
                return InkWell(
                  onTap: () => _openChapter(chapter, index: index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Text(
                      'Chapter $number  $secondary',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5BB89A),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              }, childCount: _chapters.length),
            ),
          // More Stories by Author (matches video)
          if (_authorStories.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'More Stories by ${_book.author.isNotEmpty ? _book.author : 'Author'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _authorStories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final b = _authorStories[index];
                    final title = b['title'] as String? ?? '';
                    final cover =
                        b['cover_path'] as String? ??
                        b['cover_url'] as String? ??
                        '';
                    final coverResolved = cover.isEmpty
                        ? null
                        : widget.apiService.resolveAssetUrl(cover);
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StoryDetailScreen(
                              book: BookDetailModel.fromMap(b),
                              apiService: widget.apiService,
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: coverResolved == null
                                  ? Container(
                                      width: 100,
                                      height: 140,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.menu_book),
                                    )
                                  : Image.network(
                                      coverResolved,
                                      width: 100,
                                      height: 140,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 100,
                                        height: 140,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // You May Also Like (matches video)
          if (_youMayAlsoLike.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'You May Also Like',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _youMayAlsoLike.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final b = _youMayAlsoLike[index];
                    final title = b['title'] as String? ?? '';
                    final cover =
                        b['cover_path'] as String? ??
                        b['cover_url'] as String? ??
                        '';
                    final coverResolved = cover.isEmpty
                        ? null
                        : widget.apiService.resolveAssetUrl(cover);
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StoryDetailScreen(
                              book: BookDetailModel.fromMap(b),
                              apiService: widget.apiService,
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: coverResolved == null
                                  ? Container(
                                      width: 100,
                                      height: 140,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.menu_book),
                                    )
                                  : Image.network(
                                      coverResolved,
                                      width: 100,
                                      height: 140,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 100,
                                        height: 140,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _readNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Read Now',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagBooksScreen extends StatelessWidget {
  const _TagBooksScreen({
    required this.tag,
    required this.books,
    required this.apiService,
  });

  final String tag;
  final List<Map<String, dynamic>> books;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tag.startsWith('#') ? tag : '#$tag')),
      body: books.isEmpty
          ? const Center(child: Text('No stories with this tag yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final b = books[index];
                final title = b['title'] as String? ?? 'Untitled';
                final author = b['author'] as String? ?? '';
                final cover = b['cover_path'] as String? ?? '';
                return ListTile(
                  leading: cover.isEmpty
                      ? const Icon(Icons.menu_book)
                      : Image.network(
                          apiService.resolveAssetUrl(cover),
                          width: 40,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image),
                        ),
                  title: Text(title),
                  subtitle: Text(author),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: apiService,
                          book: BookDetailModel.fromMap(b),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}



class _BookReviewsPage extends StatefulWidget {
  const _BookReviewsPage({
    required this.book,
    required this.apiService,
    required this.isOwner,
    required this.hasMyReview,
    required this.onReviewPosted,
  });

  final BookDetailModel book;
  final ApiService apiService;
  final bool isOwner;
  final bool hasMyReview;
  final Future<void> Function() onReviewPosted;

  @override
  State<_BookReviewsPage> createState() => _BookReviewsPageState();
}

class _BookReviewsPageState extends State<_BookReviewsPage> {
  List<Map<String, dynamic>> _reviews = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.apiService.fetchBookReviews(widget.book.id);
      if (mounted) {
        setState(() {
          _reviews = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                Text(
                  '${_reviews.length} reviews for',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.book.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'By ${widget.book.author}',
                  style: const TextStyle(
                    color: Color(0xFF00A651),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (!widget.isOwner)
                  Center(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      onPressed: widget.hasMyReview
                          ? null
                          : () async {
                              final posted = await Navigator.of(context).push(
                                MaterialPageRoute<bool>(
                                  builder: (_) => _WriteReviewScreen(
                                    bookId: widget.book.id,
                                    apiService: widget.apiService,
                                  ),
                                ),
                              );
                              if (posted == true) {
                                await widget.onReviewPosted();
                                await _load();
                              }
                            },
                      child: Text(
                        widget.hasMyReview ? 'You already reviewed' : 'Write a Review',
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (_reviews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No reviews yet. Be the first!',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  for (final r in _reviews) _reviewCard(r),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border),
                  Text('Save', style: TextStyle(fontSize: 12)),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ios_share),
                  Text('Share', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> r) {
    final name = (r['user_name'] ?? r['display_name'] ?? r['username'] ?? 'Reader')
        .toString();
    final body = (r['comment'] ?? r['body'] ?? r['text'] ?? '').toString();
    final title = (r['title'] ?? '').toString();
    final rating = (r['rating'] as num?)?.toDouble() ?? 0;
    final created = (r['created_at'] ?? '').toString();
    final chaptersRead = r['chapters_read'];

    Widget stars(double v) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          return Icon(
            i < v.round() ? Icons.star : Icons.star_border,
            size: 16,
            color: const Color(0xFFFFC107),
          );
        }),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (chaptersRead != null)
                      Text(
                        '$chaptersRead chapters read',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              Text(
                created.length >= 10 ? created.substring(0, 10) : created,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"$body"', style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overall Rating', style: TextStyle(fontSize: 12)),
                    stars(rating),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Plot', style: TextStyle(fontSize: 12)),
                    stars(rating),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Writing Style', style: TextStyle(fontSize: 12)),
                    stars(rating),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Grammar & Punctuation', style: TextStyle(fontSize: 12)),
                    stars(rating),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Was this review helpful to you?',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(onPressed: () {}, child: const Text('Yes')),
              TextButton(onPressed: () {}, child: const Text('No')),
            ],
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _WriteReviewScreen extends StatefulWidget {
  const _WriteReviewScreen({required this.bookId, required this.apiService});

  final int bookId;
  final ApiService apiService;

  @override
  State<_WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<_WriteReviewScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  int _overall = 0;
  int _plot = 0;
  int _style = 0;
  int _tech = 0;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Widget _starRow(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => onChanged(star),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    star <= value
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 34,
                    color: star <= value
                        ? const Color(0xFFF3C623)
                        : const Color(0xFFCCCCCC),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_overall < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please rate this novel')));
      return;
    }
    final body = _bodyCtrl.text.trim();
    // Any length allowed (including short) — rating is the only required field
    setState(() => _saving = true);
    try {
      await widget.apiService.createBookReview(widget.bookId, {
        'rating': _overall,
        'title': '',
        'comment': body,
        'plot_rating': _plot > 0 ? _plot : _overall,
        'style_rating': _style > 0 ? _style : _overall,
        'tech_rating': _tech > 0 ? _tech : _overall,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review posted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to post review: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Write Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Remember, we write reviews in order to help others find good novels. Keep this in mind when writing your review. Describe what you found special about this novel, and why you think someone else should read it.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            _starRow(
              'How do you rate this novel so far?',
              _overall,
              (v) => setState(() => _overall = v),
            ),
            _starRow(
              'How do you rate the plot of this novel?',
              _plot,
              (v) => setState(() => _plot = v),
            ),
            _starRow(
              "How do you rate the author's writing style?",
              _style,
              (v) => setState(() => _style = v),
            ),
            _starRow(
              "How do you rate the author's technical writing skills?\n(Punctuation, Grammar etc.)",
              _tech,
              (v) => setState(() => _tech = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 6,
              style: const TextStyle(fontSize: 15, height: 1.4),
              decoration: InputDecoration(
                hintText:
                    'Write your review...\nWhat did you like? Who should read this?',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  height: 1.4,
                ),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00A88E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Post',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
