import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'chapter_reader_screen.dart';
import 'hashtag_detail_screen.dart';

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
  int _reviewCount = 0;
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
    // Resolve current user immediately so owner self-actions stay disabled
    try {
      final me = await widget.apiService.fetchMe();
      final uid =
          (me['id'] as num?)?.toInt() ?? (me['user_id'] as num?)?.toInt();
      if (mounted && uid != null) setState(() => _currentUserId = uid);
    } catch (_) {}
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
          _reviewCount =
              (detail['reviews_count'] as num?)?.toInt() ??
              (detail['review_count'] as num?)?.toInt() ??
              _reviewCount;
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
          _reviews = _dedupeReviews(reviews);
          _reviewCount = _reviews.length;
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
      // You May Also Like + Recommended: tag → genre → search → bootstrap cache
      try {
        List<Map<String, dynamic>> related = [];
        Future<void> addFrom(List<Map<String, dynamic>> src) async {
          for (final b in src) {
            final id = (b['id'] as num?)?.toInt() ?? 0;
            if (id <= 0 || id == _book.id) continue;
            if (related.any((x) => (x['id'] as num?)?.toInt() == id)) continue;
            related.add(b);
            if (related.length >= 12) break;
          }
        }

        if (_tags.isNotEmpty) {
          try {
            await addFrom(await widget.apiService.fetchBooksByTag(_tags.first));
          } catch (_) {}
        }
        if (related.length < 8 && _book.genre.isNotEmpty) {
          try {
            await addFrom(await widget.apiService.fetchBooksByTag(_book.genre));
          } catch (_) {}
          try {
            await addFrom(
              await widget.apiService.searchStories(query: _book.genre),
            );
          } catch (_) {}
        }
        if (related.length < 8) {
          try {
            final boot = await widget.apiService.loadDiskBootstrap();
            if (boot != null) {
              final maps = <Map<String, dynamic>>[];
              for (final b in [
                ...boot.discoverBooks,
                ...boot.recentlyUpdated,
              ]) {
                maps.add({
                  'id': b.id,
                  'title': b.title,
                  'author': b.author,
                  'cover_path': b.coverPath,
                  'description': b.description,
                  'genre': b.primaryGenre,
                  'rating': b.rating,
                  'status_text': b.statusText,
                });
              }
              await addFrom(maps);
            }
          } catch (_) {}
        }
        if (related.length < 6) {
          try {
            // Popular / broad search fallback so sections are rarely empty
            await addFrom(
              await widget.apiService.searchStories(
                query: _book.title.split(' ').first,
              ),
            );
          } catch (_) {}
        }

        if (mounted)
          setState(() => _youMayAlsoLike = related.take(12).toList());
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

  Future<void> _toggleLike() async {
    if (_isOwner || _likeBusy) return;
    setState(() => _likeBusy = true);
    try {
      final res = _liked
          ? await widget.apiService.unlikeBook(_book.id)
          : await widget.apiService.likeBook(_book.id);
      if (!mounted) return;
      setState(() {
        final wasLiked = _liked;
        if (res.containsKey('liked')) {
          _liked = res['liked'] == true;
        } else {
          _liked = !wasLiked;
        }
        final c =
            (res['likes_count'] as num?)?.toInt() ??
            (res['likes'] as num?)?.toInt();
        if (c != null) {
          _likesCount = c;
        } else if (_liked != wasLiked) {
          _likesCount = (_likesCount + (_liked ? 1 : -1)).clamp(0, 1 << 30);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update like: $e')));
      }
    } finally {
      if (mounted) setState(() => _likeBusy = false);
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

  Future<void> _openReviewsPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _BookReviewsPage(
          book: _book,
          apiService: widget.apiService,
          isOwner: _isOwner,
          hasMyReview: _hasMyReview,
          onReviewPosted: () async {
            setState(() => _hasMyReview = true);
            final reviews = await widget.apiService.fetchBookReviews(_book.id);
            if (mounted) setState(() => _reviews = _dedupeReviews(reviews));
          },
        ),
      ),
    );
    // Always refresh counts when returning from reviews page
    try {
      final reviews = await widget.apiService.fetchBookReviews(_book.id);
      if (mounted) {
        setState(() {
          _reviews = _dedupeReviews(reviews);
          _reviewCount = _reviews.length;
          if (result == true) _hasMyReview = true;
        });
      }
    } catch (_) {}
  }

  void _onWriteReviewPressed() {
    if (_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Author can't make reviews on their own book"),
        ),
      );
      return;
    }
    if (_hasMyReview) {
      _openReviewsPage();
      return;
    }
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => _WriteReviewScreen(
              apiService: widget.apiService,
              bookId: _book.id,
            ),
          ),
        )
        .then((ok) async {
          if (ok == true && mounted) {
            setState(() => _hasMyReview = true);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Review added')));
            try {
              final reviews = await widget.apiService.fetchBookReviews(
                _book.id,
              );
              if (mounted) {
                setState(() {
                  _reviews = _dedupeReviews(reviews);
                  _reviewCount = _reviews.length;
                });
              }
            } catch (_) {}
          }
        });
  }

  Future<void> _checkSavedAndReviewed() async {
    int? viewerId;
    try {
      final me = await widget.apiService.fetchMe();
      final uid =
          (me['id'] as num?)?.toInt() ?? (me['user_id'] as num?)?.toInt();
      viewerId = uid;
      if (mounted && uid != null) setState(() => _currentUserId = uid);
    } catch (_) {}
    try {
      final lib = await widget.apiService.fetchLibraryEntries();
      final saved = lib.any((e) {
        final bid =
            (e['book_id'] as num?)?.toInt() ??
            ((e['book'] as Map?)?['id'] as num?)?.toInt() ??
            0;
        return bid == _book.id;
      });
      if (mounted) setState(() => _saved = saved);
    } catch (_) {}
    try {
      final reviews = await widget.apiService.fetchBookReviews(_book.id);
      // Support both the new is_mine flag and older deployments that only
      // return the review author's user_id.
      final mine = reviews.any(
        (r) =>
            _asTruthy(r['is_mine'] ?? r['mine']) ||
            (viewerId != null && (r['user_id'] as num?)?.toInt() == viewerId),
      );
      if (mounted && mine) setState(() => _hasMyReview = true);
    } catch (_) {}
  }

  bool _asTruthy(dynamic value) {
    if (value == true || value == 1 || value == '1') return true;
    return value?.toString().toLowerCase() == 'true';
  }

  List<Map<String, dynamic>> _dedupeReviews(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final r in list) {
      final id =
          (r['id'] ?? r['review_id'] ?? '${r['user_id']}_${r['created_at']}')
              .toString();
      if (seen.contains(id)) continue;
      seen.add(id);
      out.add(r);
    }
    return out;
  }

  bool _isDraftStory() {
    final s = (_book.statusText).toLowerCase().trim();
    return s == 'draft' || s.contains('draft');
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
    if (_isDraftStory() && !_isOwner) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This story is still a draft and not available to read yet.',
          ),
        ),
      );
      return;
    }
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
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            HashtagDetailScreen(tag: tag, apiService: widget.apiService),
      ),
    );
  }

  Widget _statCell(String label, String value) {
    // IMPORTANT: do not return Expanded here — callers may wrap in GestureDetector.
    return Column(
      mainAxisSize: MainAxisSize.min,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final muted = isDark ? Colors.white70 : Colors.black54;
    const inkittGreen = Color(0xFF6C3CE1); // brand purple

    final coverUrl = _book.coverPath.trim().isEmpty
        ? null
        : widget.apiService.resolveAssetUrl(_book.coverPath);
    final summary = _book.description.trim().isEmpty
        ? 'No summary available.'
        : _book.description.trim();
    final needsExpand = summary.length > 180;
    final authorName = _book.author.trim().isEmpty
        ? 'Author'
        : _book.author.trim();

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: inkittGreen,
        onRefresh: () async {
          await _bootstrap();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // App bar
            SliverAppBar(
              pinned: true,
              backgroundColor: bg,
              foregroundColor: fg,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Always return to home (Discover) shell
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.ios_share_outlined),
                  onPressed: _openReadingListPicker,
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
                    if (!mounted) return;
                    if (action == 'list') {
                      await _openReadingListPicker();
                    } else if (action == 'review') {
                      _onWriteReviewPressed();
                    } else if (action == 'report') {
                      try {
                        await widget.apiService.reportBook(_book.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report submitted. Thank you.'),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Report failed: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),

            // Cover — fixed size so it never becomes a full-screen gray block
            // title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 160,
                        height: 230,
                        child: coverUrl == null
                            ? ColoredBox(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.menu_book, size: 48),
                              )
                            : Image.network(
                                coverUrl,
                                width: 160,
                                height: 230,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return ColoredBox(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: Colors.grey.shade300,
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 40,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _book.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'by $authorName',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),

            // Stats
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _statCell(
                        'Chapters',
                        _loadingChapters ? '…' : '${_chapters.length}',
                      ),
                    ),
                    Expanded(
                      child: _statCell(
                        'Status',
                        _book.statusText.isNotEmpty
                            ? _book.statusText
                            : 'Ongoing',
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 16,
                                color: muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_viewCount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: fg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Views',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Summary
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      maxLines: _summaryExpanded || !needsExpand ? null : 5,
                      overflow: _summaryExpanded || !needsExpand
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF444444),
                      ),
                    ),
                    if (needsExpand)
                      TextButton(
                        onPressed: () => setState(
                          () => _summaryExpanded = !_summaryExpanded,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: inkittGreen,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          _summaryExpanded ? 'Show less' : 'Read More',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Like / Save / Reviews
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: (_likeBusy || _isOwner) ? null : _toggleLike,
                        icon: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _isOwner
                              ? Colors.grey
                              : (_liked ? Colors.red : fg),
                        ),
                        label: Text(
                          '$_likesCount',
                          style: TextStyle(color: fg),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _isOwner ? null : _openReadingListPicker,
                        icon: Icon(
                          _saved ? Icons.bookmark : Icons.bookmark_border,
                          color: _isOwner
                              ? Colors.grey
                              : (_saved ? inkittGreen : fg),
                        ),
                        label: Text('Save', style: TextStyle(color: fg)),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _openReviewsPage,
                        icon: Icon(
                          _hasMyReview ? Icons.star : Icons.star_border,
                          color: _hasMyReview ? inkittGreen : fg,
                        ),
                        label: Text(
                          '$_reviewCount',
                          style: TextStyle(color: fg),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Genre
            if (_book.genre.trim().isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Genres',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final g in _book.genre.split(RegExp(r'[,/|]')))
                            if (g.trim().isNotEmpty)
                              Chip(
                                label: Text(g.trim()),
                                backgroundColor: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF3F0FF),
                                side: BorderSide.none,
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Tags
            if (_tags.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tags',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final t in _tags)
                            ActionChip(
                              label: Text(
                                t.startsWith('#') ? t.substring(1) : t,
                                style: const TextStyle(
                                  color: Color(0xFF6C3CE1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () => _openTag(t),
                              backgroundColor: const Color(0xFFEDE9FE),
                              side: BorderSide.none,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Author row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Author',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
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
                                  authorName.isNotEmpty
                                      ? authorName[0].toUpperCase()
                                      : 'A',
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            authorName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: fg,
                            ),
                          ),
                        ),
                        if (!_isOwner && (_book.authorUserId ?? 0) > 0)
                          TextButton(
                            onPressed: _loadingFollow ? null : _toggleFollow,
                            style: TextButton.styleFrom(
                              backgroundColor: inkittGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(_isFollowing ? 'Following' : 'Follow'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Chapters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Chapters',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: fg,
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No chapters published yet.',
                    style: TextStyle(color: muted),
                  ),
                ),
              )
            else
              // ignore: prefer_const_constructors - dynamic list
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final chapter = _chapters[index];
                  final rawTitle = (chapter['title'] as String? ?? '').trim();
                  final number =
                      (chapter['chapter_number'] as num?)?.toInt() ?? index + 1;
                  final label = rawTitle.isEmpty
                      ? 'Chapter $number'
                      : 'Chapter $number  $rawTitle';
                  return ListTile(
                    title: Text(
                      label,
                      style: TextStyle(
                        color: inkittGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _openChapter(chapter, index: index),
                  );
                }, childCount: _chapters.length),
              ),

            // More stories by this author
            if (_authorStories.isNotEmpty)
              SliverToBoxAdapter(
                child: _HorizontalBookRail(
                  title: 'More stories by author',
                  books: _authorStories,
                  apiService: widget.apiService,
                ),
              ),

            // Hidden: other authors' recommendation rails (You may also like / Recommended)
            // Keep only "More stories by author" above.
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _readNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: inkittGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Read Now',
                  maxLines: 1,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
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
                      color: Color(0xFF6C3CE1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.isOwner)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        "Authors can't write reviews on their own books. You can still read reviews below.",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (!widget.isOwner)
                    Center(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6C3CE1),
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

                                if (posted == true && mounted) {
                                  // Leave reviews page immediately; parent refreshes counts
                                  Navigator.of(context).pop(true);
                                }
                              },
                        child: Text(
                          widget.hasMyReview
                              ? 'You already reviewed'
                              : 'Write a Review',
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
    final name =
        (r['user_name'] ?? r['display_name'] ?? r['username'] ?? 'Reader')
            .toString();
    final body =
        (r['comment'] ??
                r['body'] ??
                r['review'] ??
                r['review_text'] ??
                r['text'] ??
                '')
            .toString()
            .trim();
    final title = (r['title'] ?? '').toString();
    final rating = (r['rating'] as num?)?.toDouble() ?? 0;
    final plotRating = (r['plot_rating'] ?? r['plot_score'] ?? rating) is num
        ? ((r['plot_rating'] ?? r['plot_score'] ?? rating) as num).toDouble()
        : rating;
    final styleRating =
        (r['style_rating'] ?? r['writing_score'] ?? rating) is num
        ? ((r['style_rating'] ?? r['writing_score'] ?? rating) as num)
              .toDouble()
        : rating;
    final techRating = (r['tech_rating'] ?? r['grammar_score'] ?? rating) is num
        ? ((r['tech_rating'] ?? r['grammar_score'] ?? rating) as num).toDouble()
        : rating;
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
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (chaptersRead != null)
                      Text(
                        '$chaptersRead chapters read',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"$body"',
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Rating',
                      style: TextStyle(fontSize: 12),
                    ),
                    stars(rating),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Plot', style: TextStyle(fontSize: 12)),
                    stars(plotRating),
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
                    stars(styleRating),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grammar & Punctuation',
                      style: TextStyle(fontSize: 12),
                    ),
                    stars(techRating),
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
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      try {
        final reviews = await widget.apiService.fetchBookReviews(widget.bookId);
        final me = await widget.apiService.fetchMe();
        final userId =
            (me['id'] as num?)?.toInt() ?? (me['user_id'] as num?)?.toInt();
        final saved = reviews.any(
          (review) =>
              userId != null &&
              ((review['user_id'] as num?)?.toInt() == userId),
        );
        if (saved && mounted) {
          Navigator.of(context).pop(true);
          return;
        }
      } catch (_) {}
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
                  backgroundColor: const Color(0xFF6C3CE1),
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

class _HorizontalBookRail extends StatelessWidget {
  const _HorizontalBookRail({
    required this.title,
    required this.books,
    required this.apiService,
  });

  final String title;
  final List<Map<String, dynamic>> books;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A1A);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: fg,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final b = books[i];
                final id = (b['id'] as num?)?.toInt() ?? 0;
                final title = (b['title'] ?? 'Story').toString();
                final author = (b['author'] ?? '').toString();
                final cover = (b['cover_path'] ?? b['cover_url'] ?? '')
                    .toString();
                final url = cover.isNotEmpty
                    ? apiService.resolveAssetUrl(cover)
                    : '';
                return GestureDetector(
                  onTap: () {
                    if (id <= 0) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: apiService,
                          book: BookDetailModel(
                            id: id,
                            title: title,
                            author: author,
                            description: (b['description'] ?? '').toString(),
                            statusText: (b['status_text'] ?? '').toString(),
                            rating: (b['rating'] as num?)?.toDouble() ?? 0,
                            genre: (b['genre'] ?? b['primary_genre'] ?? '')
                                .toString(),
                            cta: 'Read now',
                            coverPath: cover,
                            authorUserId:
                                (b['author_user_id'] as num?)?.toInt() ??
                                (b['user_id'] as num?)?.toInt(),
                          ),
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: url.isNotEmpty
                              ? Image.network(
                                  url,
                                  width: 110,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 110,
                                    height: 150,
                                    color: const Color(0xFFEDE9FE),
                                  ),
                                )
                              : Container(
                                  width: 110,
                                  height: 150,
                                  color: const Color(0xFFEDE9FE),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
