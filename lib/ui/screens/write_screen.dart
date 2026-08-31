import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'create_story_screen.dart';
import 'edit_chapter_screen.dart';
import 'story_detail_screen.dart';

class WriteScreen extends StatefulWidget {
  const WriteScreen({super.key, required this.data, required this.apiService});

  final AppBootstrap data;
  final ApiService apiService;

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen>
    with TickerProviderStateMixin {
  late TabController _mainTabs;
  late TabController _storySubTabs;
  late TabController _analyticsSubTabs;
  late Future<List<Map<String, dynamic>>> _storiesFuture;

  String _query = '';
  /// all | ongoing | completed | recent
  String _listFilter = 'all';

  @override
  void initState() {
    super.initState();
    _mainTabs = TabController(length: 2, vsync: this);
    // ALWAYS use fixed Submitted / Drafts tabs.
    // Backend bootstrap used to send "Stories,Series" which broke filtering
    // so lists looked empty after creating a chapter.
    _storySubTabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: 1, // Drafts — where Ongoing/Draft stories land
    );
    _analyticsSubTabs = TabController(length: 2, vsync: this);
    _storiesFuture = widget.apiService.fetchWriterStories();
    _mainTabs.addListener(() => setState(() {}));
    _storySubTabs.addListener(() {
      if (!_storySubTabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _mainTabs.dispose();
    _storySubTabs.dispose();
    _analyticsSubTabs.dispose();
    super.dispose();
  }

  Future<void> _reloadStories() async {
    if (!mounted) return;
    setState(() {
      _storiesFuture = widget.apiService.fetchWriterStories();
    });
  }

  Future<void> _openCreateStory({Map<String, dynamic>? story}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            CreateStoryScreen(apiService: widget.apiService, story: story),
      ),
    );
    if (!mounted || result != true) return;
    await _reloadStories();
    // After publishing flow, show Submitted
    if (_mainTabs.index != 0) _mainTabs.animateTo(0);
    _storySubTabs.animateTo(0);
  }

  Future<void> _openEditChapter(Map<String, dynamic> story) async {
    final storyId = (story['id'] as num?)?.toInt();
    if (storyId == null) return;

    List<Map<String, dynamic>> chapters = const [];
    try {
      chapters = await widget.apiService.fetchStoryChapters(storyId);
    } catch (_) {}

    if (!mounted) return;

    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chapters — ${story['title'] ?? 'Story'}',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (chapters.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No chapters yet. Add the first one.'),
                  ),
                for (final c in chapters)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        '${(c['chapter_number'] as num?)?.toInt() ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    title: Text(
                      (c['title'] ??
                              'Chapter ${(c['chapter_number'] as num?)?.toInt() ?? ''}')
                          .toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      (c['submission_status'] ?? 'draft').toString(),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => Navigator.pop(ctx, c),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add new chapter'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    if (choice == 'new') {
      await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute<Map<String, dynamic>>(
          builder: (_) => EditChapterScreen(
            apiService: widget.apiService,
            storyId: storyId,
            createNew: true,
            chapterTitle: 'Chapter ${(chapters.length + 1)}',
          ),
        ),
      );
      await _reloadStories();
    } else if (choice is Map<String, dynamic>) {
      final id = (choice['id'] as num?)?.toInt();
      final chapterNo = (choice['chapter_number'] as num?)?.toInt();
      final title = (choice['title'] ?? 'Chapter').toString();
      await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute<Map<String, dynamic>>(
          builder: (_) => EditChapterScreen(
            apiService: widget.apiService,
            storyId: storyId,
            chapterId: id,
            chapterNumber: chapterNo,
            chapterTitle: title,
          ),
        ),
      );
      await _reloadStories();
    }
  }

  
  Future<void> _changeStoryStatus(Map<String, dynamic> story, String status) async {
    final id = (story['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    try {
      await widget.apiService.updateWriterStory(id, {'status_text': status});
      if (!mounted) return;
      final msg = status == 'Draft'
          ? 'Unpublished — moved to Drafts'
          : status == 'Completed'
              ? 'Marked as Completed'
              : 'Marked as Ongoing';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _reloadStories();
      // Jump to the right tab for the new status
      if (status == 'Draft') {
        _storySubTabs.animateTo(1);
      } else {
        _storySubTabs.animateTo(0);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    }
  }

Future<void> _deleteStory(Map<String, dynamic> story) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: Text('Delete "${story['title']}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (approved != true) return;

    await widget.apiService.deleteWriterStory(story['id'] as int);
    if (mounted) {
      await _reloadStories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text(
                'Write',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: fg,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2140) : const Color(0xFFF3EEFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4C3A7A) : const Color(0xFFD6C7FF),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.diamond_outlined, size: 14, color: Color(0xFF6C3CE1)),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6C3CE1),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openCreateStory(),
                icon: Icon(Icons.add_circle_rounded, size: 30, color: AppTheme.brand),
                tooltip: 'Create Story',
              ),
            ],
          ),
        ),
        // Hero banner (UI only — same create action)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: GestureDetector(
            onTap: () => _openCreateStory(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF3B2A6B), Color(0xFF1A1228)]
                      : const [Color(0xFF6C3CE1), Color(0xFF9B6DFF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C3CE1).withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Start Writing',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Turn your ideas into stories readers will love.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 12),
                        // CTA chip
                      ],
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Writing tools row (visual shortcuts → same create / manage)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _WriteToolChip(
                  icon: Icons.add_box_outlined,
                  label: 'New Story',
                  onTap: () => _openCreateStory(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WriteToolChip(
                  icon: Icons.library_books_outlined,
                  label: 'My Stories',
                  onTap: () {
                    if (_mainTabs.index != 0) _mainTabs.animateTo(0);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WriteToolChip(
                  icon: Icons.insights_outlined,
                  label: 'Analytics',
                  onTap: () {
                    if (_mainTabs.index != 1) _mainTabs.animateTo(1);
                  },
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEDE9FE),
              ),
            ),
          ),
          child: TabBar(
            controller: _mainTabs,
            labelColor: AppTheme.brand,
            unselectedLabelColor: isDark ? Colors.white60 : AppTheme.muted,
            indicatorColor: AppTheme.brand,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Manage Stories'),
              Tab(text: 'Analytics'),
            ],
          ),
        ),
        Expanded(
          child: _mainTabs.index == 0
              ? _ManageStoriesTab(
                  storySubTabs: _storySubTabs,
                  storiesFuture: _storiesFuture,
                  listFilter: _listFilter,
                  onListFilterChange: (v) => setState(() => _listFilter = v),
                  query: _query,
                  writeModel: widget.data.writeScreen,
                  apiService: widget.apiService,
                  onQueryChange: (value) => setState(() => _query = value),
                  onCreateStory: () => _openCreateStory(),
                  onEditStory: (story) => _openCreateStory(story: story),
                  onEditChapter: _openEditChapter,
                  onDeleteStory: _deleteStory,
                  onStatusChange: _changeStoryStatus,
                  onRefresh: _reloadStories,
                )
              : _AnalyticsTab(analyticsSubTabs: _analyticsSubTabs),
        ),
      ],
    );
  }
}

class _WriteToolChip extends StatelessWidget {
  const _WriteToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F5FC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF6C3CE1)),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF3A3A3A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageStoriesTab extends StatelessWidget {
  const _ManageStoriesTab({
    required this.storySubTabs,
    required this.storiesFuture,
    required this.listFilter,
    required this.onListFilterChange,
    required this.query,
    required this.writeModel,
    required this.apiService,
    required this.onQueryChange,
    required this.onCreateStory,
    required this.onEditStory,
    required this.onEditChapter,
    required this.onDeleteStory,
    required this.onStatusChange,
    required this.onRefresh,
  });

  final TabController storySubTabs;
  final Future<List<Map<String, dynamic>>> storiesFuture;
  final String listFilter;
  final ValueChanged<String> onListFilterChange;
  final String query;
  final WriteScreenModel writeModel;
  final ApiService apiService;
  final ValueChanged<String> onQueryChange;
  final VoidCallback onCreateStory;
  final ValueChanged<Map<String, dynamic>> onEditStory;
  final ValueChanged<Map<String, dynamic>> onEditChapter;
  final ValueChanged<Map<String, dynamic>> onDeleteStory;
  final void Function(Map<String, dynamic> story, String status) onStatusChange;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFFEDE9FE),
              ),
            ),
          ),
          child: TabBar(
            controller: storySubTabs,
            labelColor: AppTheme.brand,
            unselectedLabelColor: AppTheme.muted,
            indicatorColor: AppTheme.brand,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            // Fixed labels — do not use bootstrap "Stories/Series"
            tabs: const [
              Tab(text: 'Submitted'),
              Tab(text: 'Drafts'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: TextField(
            onChanged: onQueryChange,
            decoration: InputDecoration(
              hintText: 'Search your stories…',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFF3F0FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (ctx) {
                      Widget opt(String id, String label) => ListTile(
                            title: Text(label),
                            trailing: listFilter == id
                                ? const Icon(Icons.check, color: AppTheme.brand)
                                : null,
                            onTap: () => Navigator.pop(ctx, id),
                          );
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ListTile(title: Text('Filter stories', style: TextStyle(fontWeight: FontWeight.w700))),
                            opt('all', 'All'),
                            opt('ongoing', 'Ongoing'),
                            opt('completed', 'Completed'),
                            opt('recent', 'Recently updated'),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  );
                  if (picked != null) onListFilterChange(picked);
                },
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 16, color: AppTheme.muted),
                    const SizedBox(width: 4),
                    Text(
                      listFilter == 'all'
                          ? 'Filter: All'
                          : listFilter == 'ongoing'
                              ? 'Filter: Ongoing'
                              : listFilter == 'completed'
                                  ? 'Filter: Completed'
                                  : 'Filter: Recent',
                      style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.south_rounded, size: 16, color: AppTheme.muted),
              const SizedBox(width: 4),
              Text(
                listFilter == 'recent' ? 'Sort: Newest' : writeModel.sortLabel,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: storiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Tab 0 = Submitted → Ongoing + Completed/Published
                // Tab 1 = Drafts → Draft / empty only
                final all = snapshot.data ?? <Map<String, dynamic>>[];
                bool isSubmittedStatus(Map<String, dynamic> story) {
                  final statusText =
                      story['status_text']?.toString().toLowerCase().trim() ??
                          '';
                  if (statusText.isEmpty) return false;
                  if (statusText.contains('draft')) return false;
                  return statusText.contains('ongoing') ||
                      statusText.contains('complete') ||
                      statusText.contains('publish') ||
                      statusText.contains('submitted');
                }

                var stories = all.where((story) {
                  final submitted = isSubmittedStatus(story);
                  // index 0 Submitted, index 1 Drafts
                  if (storySubTabs.index == 0 && !submitted) return false;
                  if (storySubTabs.index == 1 && submitted) return false;
                  if (query.trim().isEmpty) return true;
                  final q = query.trim().toLowerCase();
                  final title =
                      story['title']?.toString().toLowerCase() ?? '';
                  final author =
                      story['author']?.toString().toLowerCase() ?? '';
                  return title.contains(q) || author.contains(q);
                }).toList();
                // Extra toolbar filter
                if (listFilter == 'ongoing') {
                  stories = stories
                      .where((s) {
                        final st = (s['status_text'] ?? '').toString().toLowerCase();
                        return st.contains('ongoing') || st.contains('publish');
                      })
                      .toList();
                } else if (listFilter == 'completed') {
                  stories = stories
                      .where((s) {
                        final st = (s['status_text'] ?? '').toString().toLowerCase();
                        return st.contains('complete');
                      })
                      .toList();
                } else if (listFilter == 'recent') {
                  stories = List<Map<String, dynamic>>.from(stories);
                  stories.sort((a, b) {
                    final ai = (a['id'] as num?)?.toInt() ?? 0;
                    final bi = (b['id'] as num?)?.toInt() ?? 0;
                    return bi.compareTo(ai);
                  });
                }


                // One card per story (never list same book twice after chapter saves)
                final seenIds = <int>{};
                stories = stories.where((s) {
                  final id = (s['id'] as num?)?.toInt() ?? 0;
                  if (id <= 0) return true;
                  if (seenIds.contains(id)) return false;
                  seenIds.add(id);
                  return true;
                }).toList();

                if (stories.isEmpty) {
                  final onDrafts = storySubTabs.index == 1;
                  final otherCount = all.where((s) {
                    final done = isSubmittedStatus(s);
                    return onDrafts ? done : !done;
                  }).length;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 140),
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 56,
                              color: AppTheme.muted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              onDrafts
                                  ? 'No draft or ongoing stories'
                                  : 'No submitted / completed stories',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            if (otherCount > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                onDrafts
                                    ? '$otherCount completed story(ies) are under Submitted'
                                    : '$otherCount ongoing/draft story(ies) are under Drafts',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.muted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: onCreateStory,
                              child: Text(
                                writeModel.emptyCta.isNotEmpty
                                    ? writeModel.emptyCta
                                    : 'Create story',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.brand,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  itemCount: stories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    return _StoryListCard(
                      story: story,
                      apiService: apiService,
                      onEdit: () => onEditStory(story),
                      onEditChapter: () => onEditChapter(story),
                      onDelete: () => onDeleteStory(story),
                      onStatusChange: (status) => onStatusChange(story, status),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryListCard extends StatelessWidget {
  const _StoryListCard({
    required this.story,
    required this.apiService,
    required this.onEdit,
    required this.onEditChapter,
    required this.onDelete,
    required this.onStatusChange,
  });

  final Map<String, dynamic> story;
  final ApiService apiService;
  final VoidCallback onEdit;
  final VoidCallback onEditChapter;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChange;

  void _openStoryDetail(BuildContext context) {
    final id = (story['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    final title = story['title']?.toString() ?? 'Untitled';
    final author = story['author']?.toString() ?? '';
    final description = story['description']?.toString() ?? '';
    final genre = story['genre']?.toString() ?? '';
    final statusText = story['status_text']?.toString().trim() ?? 'Draft';
    final coverPath = story['cover_path']?.toString() ?? '';
    final ratingRaw = story['rating'];
    final rating = (ratingRaw is num)
        ? ratingRaw.toDouble()
        : double.tryParse('$ratingRaw') ?? 0.0;
    final authorUserId =
        (story['author_user_id'] as num?)?.toInt() ??
        (story['user_id'] as num?)?.toInt() ??
        0;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailScreen(
          apiService: apiService,
          book: BookDetailModel(
            id: id,
            title: title,
            author: author,
            description: description,
            statusText: statusText,
            rating: rating,
            genre: genre,
            cta: 'Read now',
            coverPath: coverPath,
            authorUserId: authorUserId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = story['title']?.toString() ?? 'Untitled';
    final author = story['author']?.toString() ?? '';
    final description = story['description']?.toString() ?? '';
    final genre = story['genre']?.toString() ?? '';
    final statusText = story['status_text']?.toString().trim() ?? 'Draft';
    final stLower = statusText.toLowerCase();
    // Labels: Draft | Ongoing | Completed
    final String statusLabel;
    final Color statusBg;
    final Color statusFg;
    if (stLower.contains('complete')) {
      statusLabel = 'Completed';
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF047857);
    } else if (stLower.contains('ongoing') || stLower.contains('publish')) {
      statusLabel = 'Ongoing';
      statusBg = const Color(0xFFEDE9FE);
      statusFg = const Color(0xFF6C3CE1);
    } else {
      statusLabel = 'Draft';
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFB45309);
    }
    final coverPath = story['cover_path']?.toString() ?? '';
    final coverUrl = coverPath.isEmpty ? '' : apiService.resolveAssetUrl(coverPath);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openStoryDetail(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1A1A)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFFEDE9FE),
            ),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? const []
                : [
                    BoxShadow(
                      color: const Color(0xFF6C3CE1).withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 52,
                  height: 74,
                  color: AppTheme.brand.withValues(alpha: 0.14),
                  child: coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          width: 52,
                          height: 74,
                          cacheWidth: 104,
                          cacheHeight: 148,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.book_rounded,
                            color: AppTheme.brand,
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.book_rounded,
                          color: AppTheme.brand,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                    if (author.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'by $author',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                    if (genre.isNotEmpty || statusLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (genre.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.brand.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  genre,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.brand,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusFg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'chapter') onEditChapter();
                  if (value == 'complete') onStatusChange('Completed');
                  if (value == 'ongoing') onStatusChange('Ongoing');
                  if (value == 'unpublish') onStatusChange('Draft');
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) {
                  final st = (story['status_text'] ?? '').toString().toLowerCase();
                  final isDraft = st.contains('draft') || st.isEmpty;
                  final isComplete = st.contains('complete');
                  return [
                    const PopupMenuItem(value: 'edit', child: Text('Edit details')),
                    const PopupMenuItem(value: 'chapter', child: Text('Chapters')),
                    if (!isDraft && !isComplete)
                      const PopupMenuItem(value: 'complete', child: Text('Mark as Completed')),
                    if (!isDraft && isComplete)
                      const PopupMenuItem(value: 'ongoing', child: Text('Mark as Ongoing')),
                    if (!isDraft)
                      const PopupMenuItem(value: 'unpublish', child: Text('Unpublish (Draft)')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ];
                },
                icon: const Icon(Icons.more_vert_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.analyticsSubTabs});

  final TabController analyticsSubTabs;

  static const List<double> _weeklyFollowers = [0, 0, 1, 0, 1, 2, 0];
  static const List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: TabBar(
            controller: analyticsSubTabs,
            labelColor: AppTheme.brand,
            unselectedLabelColor: AppTheme.muted,
            indicatorColor: AppTheme.brand,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Stories'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: analyticsSubTabs,
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: const [
                      Expanded(
                        child: _AnalyticsStatCard(
                          title: 'Total Followers',
                          value: '0',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _AnalyticsStatCard(
                          title: 'Total Words Published',
                          value: '0',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: const [
                      Text(
                        'Weekly Followers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 170,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: _FollowerBars(values: _weeklyFollowers),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _weekDays
                              .map(
                                (e) => Text(
                                  e,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: const [
                      Text(
                        'Top Followers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 16, child: Text('U')),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Test User',
                              style: TextStyle(color: Color(0xFFBBBBBB)),
                            ),
                          ),
                          if (index < 3)
                            const Text(
                              'Follow user',
                              style: TextStyle(color: Color(0xFFBBBBBB)),
                            )
                          else
                            const Text(
                              'Not enough data.',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bar_chart_rounded,
                      size: 62,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Stories analytics',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Write more stories to unlock story-level stats',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsStatCard extends StatelessWidget {
  const _AnalyticsStatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FollowerBars extends StatelessWidget {
  const _FollowerBars({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxVal = values.fold(1.0, math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.map((value) {
        return Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barHeight = ((value / maxVal) * constraints.maxHeight)
                  .clamp(4.0, constraints.maxHeight);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withValues(
                        alpha: value > 0 ? 0.75 : 0.2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}
