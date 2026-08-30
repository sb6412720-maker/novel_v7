import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/cover_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';

import 'explore_screen.dart';
import 'profile_screen.dart';
import 'story_detail_screen.dart';
import 'chapter_reader_screen.dart';

part 'discover_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.data,
    required this.apiService,
  });

  final AppBootstrap data;
  final ApiService apiService;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  bool _isValidBook(BookCardModel b) => b.id > 0 && b.title.trim().isNotEmpty;

  late final TabController _tabController;
  late final List<String> _tabs;
  int _selectedTabIndex = 0;
  late List<BookCardModel> _shuffledBooks;
  int _shuffleToken = 0;

  void _reshuffleBooks() {
    // AppBootstrap uses discoverBooks / recentlyUpdated — not `.books`
    final pool = _booksForDiscover();
    pool.shuffle(
      math.Random(DateTime.now().millisecondsSinceEpoch + _shuffleToken),
    );
    _shuffledBooks = pool;
    _shuffleToken++;
  }

  @override
  void initState() {
    super.initState();
    _reshuffleBooks();
    // Dedupe backend tabs (was showing "New New Popular Popular…")
    final rawTabs = widget.data.discoverTabs.isNotEmpty
        ? widget.data.discoverTabs
        : const ['New', 'Popular', 'Fanfiction', 'Newsfeed'];
    final seen = <String>{};
    _tabs = <String>[];
    for (final tab in rawTabs) {
      final key = tab.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      _tabs.add(tab.trim());
    }
    if (_tabs.isEmpty) {
      _tabs = const ['New', 'Popular', 'Fanfiction', 'Newsfeed'];
    }
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prefer shuffled catalog so pull-to-refresh changes order
    final catalog = _shuffledBooks.isNotEmpty
        ? _shuffledBooks
        : _booksForDiscover();

    return RefreshIndicator(
      onRefresh: () async {
        setState(_reshuffleBooks);
        // Small delay so the indicator is visible
        await Future<void>.delayed(const Duration(milliseconds: 350));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final fg = isDark ? Colors.white : const Color(0xFF1A1A1A);
              return SliverToBoxAdapter(
                child: Container(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                  child: Row(
                    children: [
                      Text(
                        'Wingsaga',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: fg,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Search',
                        icon: Icon(Icons.search, size: 26, color: fg),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SearchScreen(apiService: widget.apiService),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'More',
                        icon: Icon(Icons.more_vert, size: 24, color: fg),
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            builder: (ctx) {
                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
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
                                    ListTile(
                                      leading: const Icon(
                                        Icons.support_agent_outlined,
                                      ),
                                      title: const Text('Contact support'),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        if (!context.mounted) return;
                                        await showModalBottomSheet<void>(
                                          context: context,
                                          isScrollControlled: true,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(16),
                                            ),
                                          ),
                                          builder: (sctx) {
                                            final subject =
                                                TextEditingController();
                                            final body =
                                                TextEditingController();
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                left: 20,
                                                right: 20,
                                                top: 20,
                                                bottom:
                                                    MediaQuery.of(
                                                      sctx,
                                                    ).viewInsets.bottom +
                                                    20,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  const Text(
                                                    'Contact support',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextField(
                                                    controller: subject,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Subject',
                                                        ),
                                                  ),
                                                  TextField(
                                                    controller: body,
                                                    maxLines: 4,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'How can we help?',
                                                        ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      try {
                                                        await widget.apiService
                                                            .submitSupportRequest(
                                                              {
                                                                'subject':
                                                                    subject.text
                                                                        .trim(),
                                                                'description':
                                                                    body.text
                                                                        .trim(),
                                                                'issue': subject
                                                                    .text
                                                                    .trim(),
                                                              },
                                                            );
                                                        if (sctx.mounted)
                                                          Navigator.pop(sctx);
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Support request sent',
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      } catch (e) {
                                                        if (sctx.mounted) {
                                                          ScaffoldMessenger.of(
                                                            sctx,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                '$e',
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                    child: const Text('Send'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.switch_account_outlined,
                                      ),
                                      title: const Text('Change account'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        // Jump user to More tab (index 4) if RootShell is parent
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Open the More tab to switch account or sign out',
                                            ),
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      title: const Text(
                                        'Cancel',
                                        textAlign: TextAlign.center,
                                      ),
                                      onTap: () => Navigator.pop(ctx),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF121212)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _CategoryTabs(
                  labels: _tabs,
                  tabController: _tabController,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildTabContent(_selectedTabIndex)),
        ],
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final tabLabel = _tabs[tabIndex].toLowerCase();
    // Use shuffled list when available so refresh changes rail order
    final allBooks = _shuffledBooks.isNotEmpty
        ? _shuffledBooks
        : _booksForDiscover();
    final sections = _discoverSectionsForTab(tabLabel, allBooks);
    final showExploreLead = tabLabel == 'new' && sections.isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.white,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          if (showExploreLead) ...[
            _ExploreStoriesSection(
              books: sections.first.books,
              topics: widget.data.exploreTopics,
              apiService: widget.apiService,
              onOpenExplore: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExploreScreen(
                      topics: widget.data.exploreTopics,
                      apiService: widget.apiService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          for (var i = 0; i < sections.length; i++) ...[
            if (!(showExploreLead && i == 0)) ...[
              _DynamicStoryRail(
                section: sections[i],
                apiService: widget.apiService,
              ),
              const SizedBox(height: 24),
            ],
            // Center of Discover page: Continue reading
            if (i == 0) ...[
              _ContinueReadingSection(
                entries: widget.data.libraryEntries,
                apiService: widget.apiService,
                onBrowse: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExploreScreen(
                        topics: widget.data.exploreTopics,
                        apiService: widget.apiService,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (!(showExploreLead && i == 0)) ...[
              if (i == 1) ...[
                _AuthorsStrip(books: allBooks, apiService: widget.apiService),
                const SizedBox(height: 24),
                _BrowseGenresSection(
                  books: allBooks,
                  topics: widget.data.exploreTopics,
                  apiService: widget.apiService,
                  onOpenExplore: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExploreScreen(
                          topics: widget.data.exploreTopics,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ],
          ],
          // If no rails, still show Continue reading centered
          if (sections.isEmpty) ...[
            _ContinueReadingSection(
              entries: widget.data.libraryEntries,
              apiService: widget.apiService,
              onBrowse: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExploreScreen(
                      topics: widget.data.exploreTopics,
                      apiService: widget.apiService,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  List<BookCardModel> _booksForDiscover() {
    final seen = <int>{};
    final merged = <BookCardModel>[];
    final source = widget.data.discoverBooks.isNotEmpty
        ? widget.data.discoverBooks
        : [...widget.data.recentlyUpdated, ...widget.data.recentlyCompleted];
    for (final book in source) {
      // Drop blanks that caused empty slots in the story slider
      if (!_isValidBook(book)) continue;
      if (seen.contains(book.id)) continue;
      seen.add(book.id);
      merged.add(book);
    }
    return merged;
  }

  List<_DiscoverRailSection> _discoverSectionsForTab(
    String tab,
    List<BookCardModel> books,
  ) {
    List<BookCardModel> takeWhere(bool Function(BookCardModel) test) {
      return books.where(test).toList();
    }

    final recentlyUpdated = takeWhere(
      (b) => b.sectionName == 'recently_updated',
    );
    final recentlyCompleted = takeWhere(
      (b) => b.sectionName == 'recently_completed' || b.isCompleted,
    );
    final topRated = [...books]..sort((a, b) => b.rating.compareTo(a.rating));
    final fantasy = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('fantasy') ||
          b.secondaryGenre.toLowerCase().contains('fantasy'),
    );
    final paranormal = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('paranormal') ||
          b.secondaryGenre.toLowerCase().contains('paranormal') ||
          b.secondaryGenre.toLowerCase().contains('urban'),
    );
    final action = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('action') ||
          b.secondaryGenre.toLowerCase().contains('action') ||
          b.primaryGenre.toLowerCase().contains('adventure') ||
          b.secondaryGenre.toLowerCase().contains('adventure'),
    );

    switch (tab) {
      case 'popular':
        return [
          _DiscoverRailSection(
            title: 'Trending Now',
            books: topRated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Most Completed',
            books: recentlyCompleted.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Fan Favorites',
            books: topRated.skip(2).take(10).toList(),
          ),
        ];
      case 'fanfiction':
        return [
          _DiscoverRailSection(
            title: 'Fan Picks',
            books: topRated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Romance & Drama',
            books: takeWhere(
              (b) =>
                  b.primaryGenre.toLowerCase().contains('romance') ||
                  b.primaryGenre.toLowerCase().contains('drama'),
            ).take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Completed Fan Stories',
            books: recentlyCompleted.take(10).toList(),
          ),
        ];
      case 'newsfeed':
        return [
          _DiscoverRailSection(
            title: 'Fresh Updates',
            books: recentlyUpdated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Staff Picks',
            books: topRated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Rising Stories',
            books: topRated.skip(4).take(10).toList(),
          ),
        ];
      default:
        return [
          _DiscoverRailSection(
            title: 'Recently Updated',
            books: recentlyUpdated.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Recently Completed',
            books: recentlyCompleted.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Selected Stories',
            books: topRated.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'New in Fantasy',
            books: fantasy.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Action & Adventure Fantasy',
            books: action.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Paranormal & Urban Fantasy',
            books: paranormal.take(12).toList(),
          ),
        ];
    }
  }
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.apiService,
    this.initialQuery = '',
    this.initialGenre = '',
  });

  final ApiService apiService;
  final String initialQuery;
  final String initialGenre;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  String _searchQuery = '';
  String _genre = '';
  double _minRating = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];

  /// Wattpad-style filter chip: title | tag | profile
  String _searchScope = 'title';

  /// Cached recent searches per scope (last 5 each).
  List<String> _recentTitle = const [];
  List<String> _recentTag = const [];
  List<String> _recentProfile = const [];
  bool _showRecent = true;
  List<Map<String, dynamic>> _recentRows = const [];

  static const _kHistTitle = 'search_hist_title_v1';
  static const _kHistTag = 'search_hist_tag_v1';
  static const _kHistProfile = 'search_hist_profile_v1';
  static const _kResultsTitle = 'search_results_title_v1';
  static const _kResultsTag = 'search_results_tag_v1';
  static const _kResultsProfile = 'search_results_profile_v1';
  Timer? _searchDebounce;

  List<String> get _recentForScope {
    switch (_searchScope) {
      case 'tag':
        return _recentTag;
      case 'profile':
        return _recentProfile;
      default:
        return _recentTitle;
    }
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawResults = prefs.getString(_resultsKey);
      final decodedResults = rawResults == null ? null : jsonDecode(rawResults);
      if (!mounted) return;
      setState(() {
        _recentTitle = prefs.getStringList(_kHistTitle) ?? const [];
        _recentTag = prefs.getStringList(_kHistTag) ?? const [];
        _recentProfile = prefs.getStringList(_kHistProfile) ?? const [];
        _recentRows = decodedResults is List
            ? decodedResults
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const [];
        // Keep recent panel open when search field is empty
        if (_searchQuery.trim().isEmpty) {
          _showRecent = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _reloadRecentForScope() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawResults = prefs.getString(_resultsKey);
      final decodedResults = rawResults == null ? null : jsonDecode(rawResults);
      if (!mounted) return;
      setState(() {
        _recentRows = decodedResults is List
            ? decodedResults
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const [];
        _showRecent = _searchQuery.trim().isEmpty;
      });
    } catch (_) {}
  }

  String get _resultsKey {
    switch (_searchScope) {
      case 'tag':
        return _kResultsTag;
      case 'profile':
        return _kResultsProfile;
      default:
        return _kResultsTitle;
    }
  }

  Future<void> _saveRecentResults(List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_resultsKey, jsonEncode(rows.take(5).toList()));
    } catch (_) {}
  }

  Future<void> _saveSearchHistory(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> list;
      String key;
      switch (_searchScope) {
        case 'tag':
          list = List<String>.from(_recentTag);
          key = _kHistTag;
          break;
        case 'profile':
          list = List<String>.from(_recentProfile);
          key = _kHistProfile;
          break;
        default:
          list = List<String>.from(_recentTitle);
          key = _kHistTitle;
      }
      list.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
      list.insert(0, q);
      if (list.length > 5) list = list.take(5).toList();
      await prefs.setStringList(key, list);
      if (!mounted) return;
      setState(() {
        switch (_searchScope) {
          case 'tag':
            _recentTag = list;
            break;
          case 'profile':
            _recentProfile = list;
            break;
          default:
            _recentTitle = list;
        }
      });
    } catch (_) {}
  }

  Future<void> _runSearch({bool recordHistory = true}) async {
    final q = _searchQuery.trim();
    // No query → only recent history chips, no random book list
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(_recentRows);
          _loading = false;
          _showRecent = true;
        });
      }
      return;
    }
    setState(() => _loading = true);
    // Persist every non-empty search per scope (title / tag / profile)
    if (recordHistory) {
      await _saveSearchHistory(q);
    }
    List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    try {
      if (_searchScope == 'tag') {
        // TAG scope: only hashtag matches (not story titles)
        final tags = await widget.apiService.fetchTags(query: q);
        final qLower = q.toLowerCase().replaceFirst('#', '');
        final matchedTags = tags
            .map((e) {
              final name = (e['name'] ?? e['tag'] ?? e['label'] ?? '')
                  .toString();
              return <String, dynamic>{
                '_kind': 'tag',
                'id': e['id'] ?? name.hashCode,
                'title': name.startsWith('#') ? name : '#$name',
                'author': 'Hashtag',
                'cover_path': '',
                'rating': '',
                'tag_name': name.replaceFirst('#', ''),
              };
            })
            .where((e) {
              final name = (e['tag_name'] ?? '').toString().toLowerCase();
              // Prefer contains match on tag name only
              return name.contains(qLower) || name == qLower;
            })
            .take(5)
            .toList();
        final bookGroups = await Future.wait(
          matchedTags.map((tag) {
            final name = (tag['tag_name'] ?? '').toString();
            return widget.apiService.fetchBooksByTag(name);
          }),
        );
        final seenBookIds = <int>{};
        rows = [
          for (var i = 0; i < bookGroups.length; i++)
            for (final book in bookGroups[i])
              if ((book['id'] as num?) != null &&
                  seenBookIds.add((book['id'] as num).toInt()))
                {
                  ...book,
                  '_kind': 'book',
                  'tag_name': matchedTags[i]['tag_name'],
                },
        ].take(30).toList();
        if (rows.isEmpty) rows = matchedTags;
      } else if (_searchScope == 'profile') {
        // PROFILE scope: only author/user profiles
        List<Map<String, dynamic>> users = const [];
        try {
          users = await widget.apiService.searchUsers(query: q);
        } catch (_) {
          users = const [];
        }
        if (users.isNotEmpty) {
          rows = users.map((u) {
            final name = (u['display_name'] ?? u['username'] ?? u['name'] ?? '')
                .toString()
                .trim();
            final username = (u['username'] ?? '').toString();
            final uid = u['id'] ?? u['user_id'];
            final photo = (u['photo_url'] ?? u['avatar_url'] ?? '').toString();
            return <String, dynamic>{
              '_kind': 'profile',
              'id': uid ?? name.hashCode,
              'title': name.isEmpty ? username : name,
              'author': username.isNotEmpty ? '@$username' : 'Author',
              'cover_path': photo,
              'rating': '',
              'author_user_id': uid,
              'photo_url': photo,
            };
          }).toList();
        } else {
          // Fallback: authors from story search, profile rows only
          final stories = await widget.apiService.searchStories(query: q);
          final seen = <String>{};
          for (final s in stories) {
            final author = (s['author'] ?? s['display_name'] ?? '')
                .toString()
                .trim();
            if (author.isEmpty) continue;
            final key = author.toLowerCase();
            if (seen.contains(key)) continue;
            if (!key.contains(q.toLowerCase())) continue;
            seen.add(key);
            final uid = s['author_user_id'] ?? s['user_id'] ?? s['author_id'];
            rows.add(<String, dynamic>{
              '_kind': 'profile',
              'id': uid ?? author.hashCode,
              'title': author,
              'author': (s['username'] ?? '').toString().isNotEmpty
                  ? '@${s['username']}'
                  : 'Author',
              'cover_path':
                  (s['author_photo'] ?? s['photo_url'] ?? s['avatar_url'] ?? '')
                      .toString(),
              'rating': '',
              'author_user_id': uid,
              'photo_url':
                  (s['author_photo'] ?? s['photo_url'] ?? s['avatar_url'] ?? '')
                      .toString(),
            });
            if (rows.length >= 30) break;
          }
        }
      } else {
        // TITLE scope: exact title match only (case-insensitive)
        final stories = await widget.apiService.searchStories(
          query: q,
          genre: _genre,
          minRating: _minRating,
        );
        final qLower = q.toLowerCase();
        rows = stories
            .where((e) {
              final title = (e['title'] ?? '').toString().trim().toLowerCase();
              return title.contains(qLower);
            })
            .map(
              (e) => <String, dynamic>{
                ...Map<String, dynamic>.from(e),
                '_kind': 'book',
              },
            )
            .toList();
      }
    } catch (_) {
      rows = <Map<String, dynamic>>[];
    }
    if (!mounted) return;
    setState(() {
      _results = rows;
      _loading = false;
      _showRecent = false;
    });
    if (recordHistory && rows.isNotEmpty) {
      await _saveRecentResults(rows);
      if (mounted) setState(() => _recentRows = rows.take(5).toList());
    }
  }

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery;
    _genre = widget.initialGenre;
    _searchController = TextEditingController(text: widget.initialQuery);
    _searchFocus = FocusNode();
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) {
        setState(() {
          _showRecent = _searchQuery.trim().isEmpty;
        });
        if (_searchQuery.trim().isEmpty) {
          unawaited(_loadSearchHistory());
        }
      }
    });
    _bootstrapSearch();
  }

  Future<void> _bootstrapSearch() async {
    await _loadSearchHistory();
    if (mounted) {
      setState(() {
        _showRecent = true;
      });
    }
    if (!mounted) return;
    if (widget.initialQuery.trim().isNotEmpty) {
      _runSearch(recordHistory: true);
    } else {
      setState(() {
        _showRecent = true;
        _results = <Map<String, dynamic>>[];
        _loading = false;
      });
    }
    // Open keyboard + keep recent chips visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
      setState(() => _showRecent = _searchQuery.trim().isEmpty);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recentForScope;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            hintText: 'Search stories, people, lists...',
            border: InputBorder.none,
            hintStyle: Theme.of(context).textTheme.bodyMedium,
          ),
          textInputAction: TextInputAction.search,
          onTap: () {
            if (_searchQuery.trim().isEmpty) {
              setState(() => _showRecent = true);
            }
          },
          onChanged: (value) {
            _searchDebounce?.cancel();
            setState(() {
              _searchQuery = value;
              _showRecent = value.trim().isEmpty;
            });
            // Don't pollute history while typing
            _searchDebounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) _runSearch(recordHistory: false);
            });
          },
          onSubmitted: (value) {
            setState(() {
              _searchQuery = value;
              _showRecent = false;
            });
            _runSearch(recordHistory: true);
          },
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _showRecent = true;
                });
                _searchController.clear();
                _runSearch();
              },
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              final selected = await showModalBottomSheet<_SearchFilters>(
                context: context,
                builder: (_) => const _FilterSheet(),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              );
              if (selected == null) return;
              setState(() {
                _genre = selected.genre;
                _minRating = selected.minRating;
              });
              _runSearch(recordHistory: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Wattpad-style scope chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                for (final entry in const [
                  {'id': 'title', 'label': 'Title'},
                  {'id': 'tag', 'label': 'Tag'},
                  {'id': 'profile', 'label': 'Profile'},
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry['label']!),
                      selected: _searchScope == entry['id'],
                      onSelected: (_) async {
                        setState(() {
                          _searchScope = entry['id']!;
                          _showRecent = _searchQuery.trim().isEmpty;
                        });
                        await _reloadRecentForScope();
                        if (_searchQuery.trim().isEmpty) {
                          // Keep chips visible; clear result list to recent only
                          if (mounted) {
                            setState(() {
                              _results = <Map<String, dynamic>>[];
                              _loading = false;
                              _showRecent = true;
                            });
                          }
                        } else {
                          _runSearch(recordHistory: false);
                        }
                      },
                      selectedColor: const Color(
                        0xFF00A88E,
                      ).withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _searchScope == entry['id']
                            ? const Color(0xFF00A88E)
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Recent searches (per scope): last 5 from local cache
          if (_showRecent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent ${_searchScope == 'tag'
                        ? 'tag'
                        : _searchScope == 'profile'
                        ? 'profile'
                        : 'title'} searches',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 4),
                      child: Text(
                        'No recent searches yet',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final term in recent.take(5))
                          ActionChip(
                            avatar: const Icon(Icons.history, size: 16),
                            label: Text(term),
                            onPressed: () {
                              _searchController.text = term;
                              setState(() {
                                _searchQuery = term;
                                _showRecent = false;
                              });
                              _runSearch(recordHistory: true);
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Search stories, tags or people'
                          : 'No results',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final kind = (item['_kind'] ?? 'book').toString();
                      final cover =
                          (item['cover_path'] ?? item['photo_url'] ?? '')
                              .toString();
                      Widget leading;
                      if (kind == 'profile') {
                        leading = CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFE8EEF9),
                          backgroundImage: cover.isNotEmpty
                              ? NetworkImage(
                                  widget.apiService.resolveAssetUrl(cover),
                                )
                              : null,
                          child: cover.isEmpty
                              ? Text(
                                  ((item['title'] ?? '?').toString().isNotEmpty
                                          ? item['title'].toString()[0]
                                          : '?')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF00A88E),
                                  ),
                                )
                              : null,
                        );
                      } else if (kind == 'tag') {
                        leading = const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFE8EEF9),
                          child: Icon(Icons.tag, color: Color(0xFF00A88E)),
                        );
                      } else {
                        leading = SizedBox(
                          width: 40,
                          height: 56,
                          child: cover.isNotEmpty
                              ? Image.network(
                                  widget.apiService.resolveAssetUrl(cover),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFE4E4E4),
                                  ),
                                )
                              : const ColoredBox(color: Color(0xFFE4E4E4)),
                        );
                      }
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                        onTap: () async {
                          if (kind == 'tag') {
                            final tag =
                                (item['tag_name'] ?? item['title'] ?? '')
                                    .toString()
                                    .replaceFirst('#', '');
                            if (tag.isEmpty) return;
                            final books = await widget.apiService
                                .fetchBooksByTag(tag);
                            if (!context.mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _GenreBooksScreen(
                                  genre: tag,
                                  books: books,
                                  apiService: widget.apiService,
                                ),
                              ),
                            );
                            return;
                          }
                          if (kind == 'profile') {
                            final uid =
                                (item['author_user_id'] as num?)?.toInt() ??
                                (item['id'] as num?)?.toInt();
                            if (uid == null || uid <= 0) return;
                            final name = (item['title'] ?? 'Author').toString();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProfileScreen(
                                  apiService: widget.apiService,
                                  viewingUserId: uid,
                                  achievements: const [],
                                  profile: ProfileModel(
                                    id: uid,
                                    displayName: name,
                                    username: name.toLowerCase().replaceAll(
                                      ' ',
                                      '',
                                    ),
                                    photoUrl: cover,
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
                            return;
                          }
                          final id = (item['id'] as num?)?.toInt();
                          if (id == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StoryDetailScreen(
                                apiService: widget.apiService,
                                book: BookDetailModel.fromMap(item),
                              ),
                            ),
                          );
                        },
                        leading: leading,
                        title: Text(item['title']?.toString() ?? ''),
                        subtitle: Text(item['author']?.toString() ?? ''),
                        trailing: kind == 'book'
                            ? Text(
                                (item['rating'] ?? '').toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            : Icon(
                                kind == 'profile'
                                    ? Icons.person_outline
                                    : Icons.chevron_right,
                                color: Colors.grey,
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

class _SearchFilters {
  const _SearchFilters({required this.genre, required this.minRating});

  final String genre;
  final double minRating;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _selectedGenre;
  double _ratingFilter = 0;
  String? _completionStatus;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Genre',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Romance', 'Fantasy', 'Mystery', 'Horror', 'Sci-Fi']
                .map(
                  (genre) => FilterChip(
                    label: Text(genre),
                    selected: _selectedGenre == genre,
                    onSelected: (selected) {
                      setState(() => _selectedGenre = selected ? genre : null);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Star Rating',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _ratingFilter,
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: (value) => setState(() => _ratingFilter = value),
          ),
          const SizedBox(height: 24),
          Text(
            'Status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Complete', 'Ongoing', 'Hiatus']
                .map(
                  (status) => FilterChip(
                    label: Text(status),
                    selected: _completionStatus == status,
                    onSelected: (selected) {
                      setState(
                        () => _completionStatus = selected ? status : null,
                      );
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                _SearchFilters(
                  genre: _selectedGenre ?? '',
                  minRating: _ratingFilter,
                ),
              ),
              child: const Text('View Results'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Story detail (matches video: cover, stats, summary, genres, chapters, CTA)
// ---------------------------------------------------------------------------
