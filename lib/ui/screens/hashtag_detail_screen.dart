import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'story_detail_screen.dart';

/// Hashtag / genre hub — UI aligned with Inkitt-style tag pages.
class HashtagDetailScreen extends StatefulWidget {
  const HashtagDetailScreen({
    super.key,
    required this.tag,
    required this.apiService,
  });

  final String tag;
  final ApiService apiService;

  @override
  State<HashtagDetailScreen> createState() => _HashtagDetailScreenState();
}

class _HashtagDetailScreenState extends State<HashtagDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _books = const [];
  List<Map<String, dynamic>> _related = const [];
  bool _loading = true;
  bool _following = false;

  String get _tagName {
    final t = widget.tag.trim();
    return t.startsWith('#') ? t.substring(1) : t;
  }

  String get _displayTag => '#$_tagName';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final books = await widget.apiService.fetchBooksByTag(_tagName);
      List<Map<String, dynamic>> related = const [];
      try {
        final tags = await widget.apiService.fetchTags();
        related = tags
            .where((t) {
              final n = (t['name'] ?? t['tag'] ?? '').toString().toLowerCase();
              return n.isNotEmpty && n != _tagName.toLowerCase();
            })
            .take(8)
            .toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _books = books;
        _related = related;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _books = const [];
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _sorted {
    final list = List<Map<String, dynamic>>.from(_books);
    switch (_tabs.index) {
      case 1: // Recent — reverse id order approx
        list.sort((a, b) => ((b['id'] as num?)?.toInt() ?? 0)
            .compareTo((a['id'] as num?)?.toInt() ?? 0));
        break;
      case 2: // Trending — views
        list.sort((a, b) => ((b['view_count'] as num?)?.toInt() ?? 0)
            .compareTo((a['view_count'] as num?)?.toInt() ?? 0));
        break;
      case 3: // Most liked
        list.sort((a, b) => ((b['likes_count'] as num?)?.toInt() ??
                (b['rating'] as num?)?.toDouble() ??
                0)
            .compareTo((a['likes_count'] as num?)?.toInt() ??
                (a['rating'] as num?)?.toDouble() ??
                0));
        break;
      default: // Top — rating then views
        list.sort((a, b) {
          final ra = (a['rating'] as num?)?.toDouble() ?? 0;
          final rb = (b['rating'] as num?)?.toDouble() ?? 0;
          if (rb != ra) return rb.compareTo(ra);
          return ((b['view_count'] as num?)?.toInt() ?? 0)
              .compareTo((a['view_count'] as num?)?.toInt() ?? 0);
        });
    }
    return list;
  }

  void _openBook(Map<String, dynamic> m) {
    final id = (m['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailScreen(
          apiService: widget.apiService,
          book: BookDetailModel(
            id: id,
            title: (m['title'] ?? 'Story').toString(),
            author: (m['author'] ?? '').toString(),
            description: (m['description'] ?? '').toString(),
            statusText: (m['status_text'] ?? '').toString(),
            rating: (m['rating'] as num?)?.toDouble() ?? 0,
            genre: (m['genre'] ?? m['primary_genre'] ?? _tagName).toString(),
            cta: 'Read Now',
            coverPath: (m['cover_path'] ?? '').toString(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = _sorted;
    final featured = sorted.take(8).toList();
    final top = sorted.take(20).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.brand))
            : RefreshIndicator(
                color: AppTheme.brand,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _header(isDark)),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _HashtagTabDelegate(
                        child: Container(
                          color: isDark ? const Color(0xFF121212) : Colors.white,
                          child: TabBar(
                            controller: _tabs,
                            isScrollable: true,
                            labelColor: AppTheme.brand,
                            unselectedLabelColor: AppTheme.muted,
                            indicatorColor: AppTheme.brand,
                            indicatorWeight: 3,
                            tabs: const [
                              Tab(text: 'Top'),
                              Tab(text: 'Recent'),
                              Tab(text: 'Trending'),
                              Tab(text: 'Most Liked'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (featured.isNotEmpty)
                      ..._featuredSection(featured, isDark),
                    ..._topStoriesSection(top, isDark),
                    if (_related.isNotEmpty) ..._relatedSection(isDark),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header(bool isDark) {
    final cover = _books.isNotEmpty
        ? (_books.first['cover_path'] ?? '').toString()
        : '';
    final coverUrl =
        cover.isEmpty ? null : widget.apiService.resolveAssetUrl(cover);
    final count = _books.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.ios_share_outlined), onPressed: () {}),
              IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTag,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count ${count == 1 ? 'story' : 'stories'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stories tagged $_displayTag — discover top picks, trending reads, and related hashtags.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                setState(() => _following = !_following),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.brand,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: Icon(
                              _following ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                            ),
                            label: Text(_following ? 'Following' : 'Follow'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.brand,
                              side: const BorderSide(color: Color(0xFFEDE9FE)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(Icons.notifications_none, size: 18),
                            label: const Text('Notify'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 110,
                    height: 110,
                    color: const Color(0xFFF3F0FF),
                    child: coverUrl == null
                        ? const Icon(Icons.tag, size: 40, color: AppTheme.brand)
                        : Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.tag, color: AppTheme.brand),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _featuredSection(List<Map<String, dynamic>> books, bool isDark) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Text(
                'Featured Stories',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                'See All',
                style: TextStyle(
                  color: AppTheme.brand,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final m = books[i];
              final cover = (m['cover_path'] ?? '').toString();
              final url = cover.isEmpty
                  ? null
                  : widget.apiService.resolveAssetUrl(cover);
              return GestureDetector(
                onTap: () => _openBook(m),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 120,
                                color: const Color(0xFFF3F0FF),
                                child: url == null
                                    ? const Icon(Icons.menu_book)
                                    : Image.network(url, fit: BoxFit.cover,
                                        width: 120, height: double.infinity,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.menu_book)),
                              ),
                            ),
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.brand,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Featured',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (m['title'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      Text(
                        'by ${(m['author'] ?? '').toString()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _topStoriesSection(
      List<Map<String, dynamic>> books, bool isDark) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              const Text(
                'Top Stories',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                'Sort by Top',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final m = books[i];
            final cover = (m['cover_path'] ?? '').toString();
            final url = cover.isEmpty
                ? null
                : widget.apiService.resolveAssetUrl(cover);
            final title = (m['title'] ?? 'Story').toString();
            final author = (m['author'] ?? '').toString();
            final desc = (m['description'] ?? '').toString();
            final status = (m['status_text'] ?? '').toString();
            final genre = (m['genre'] ?? m['primary_genre'] ?? _tagName).toString();
            final views = (m['view_count'] as num?)?.toInt() ?? 0;
            final rating = (m['rating'] as num?)?.toDouble() ?? 0;
            return InkWell(
              onTap: () => _openBook(m),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 56,
                        height: 72,
                        color: const Color(0xFFF3F0FF),
                        child: url == null
                            ? const Icon(Icons.menu_book, size: 20)
                            : Image.network(url, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.menu_book, size: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14)),
                          Text('by $author',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          if (desc.isNotEmpty)
                            Text(desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    height: 1.25)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (genre.isNotEmpty)
                                _chip(genre, const Color(0xFFFCE7F3),
                                    const Color(0xFFBE185D)),
                              if (status.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                _chip(
                                  status,
                                  const Color(0xFFD1FAE5),
                                  const Color(0xFF047857),
                                ),
                              ],
                              const Spacer(),
                              Icon(Icons.visibility_outlined,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Text('$views',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                              const SizedBox(width: 8),
                              const Icon(Icons.star_rounded,
                                  size: 14, color: Color(0xFFF3C623)),
                              Text(rating.toStringAsFixed(1),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: books.length,
        ),
      ),
    ];
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  List<Widget> _relatedSection(bool isDark) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: const Text(
            'Related Hashtags',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final t = _related[i];
              final name = (t['name'] ?? t['tag'] ?? '').toString();
              final count = (t['book_count'] as num?)?.toInt() ?? 0;
              return InkWell(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => HashtagDetailScreen(
                        tag: name,
                        apiService: widget.apiService,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF7F5FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEDE9FE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name.startsWith('#') ? name : '#$name',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      Text(
                        '$count stories',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

class _HashtagTabDelegate extends SliverPersistentHeaderDelegate {
  _HashtagTabDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _HashtagTabDelegate oldDelegate) =>
      oldDelegate.child != child;
}
