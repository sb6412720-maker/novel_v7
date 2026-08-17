import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'story_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _ongoing = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _saved = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService.instance;
      final reading = await api.getReadingList();
      final ongoing = <Map<String, dynamic>>[];
      final history = <Map<String, dynamic>>[];
      for (final item in reading) {
        final total = (item['total_chapters'] as num?)?.toInt() ?? 0;
        final read = (item['chapters_read'] as num?)?.toInt() ?? 0;
        if (total > 0 && read >= total) {
          history.add(item);
        } else {
          ongoing.add(item);
        }
      }
      final saved = await api.getSavedBooks();
      if (mounted) {
        setState(() {
          _ongoing = ongoing;
          _history = history;
          _saved = saved;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ongoing Reading'),
            Tab(text: 'History'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_ongoing, emptyMsg: 'No books in progress'),
                    _buildList(_history, emptyMsg: 'No completed books yet'),
                    _buildList(_saved, emptyMsg: 'No saved books'),
                  ],
                ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required String emptyMsg}) {
    if (items.isEmpty) {
      return Center(child: Text(emptyMsg, style: TextStyle(color: Colors.grey[600])));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final title = item['title']?.toString() ?? 'Untitled';
          final cover = item['cover_path']?.toString() ?? '';
          final progress = item['chapters_read'];
          final total = item['total_chapters'];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: cover.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        ApiService.instance.resolveAssetUrl(cover),
                        width: 48,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 40),
                      ),
                    )
                  : const Icon(Icons.book, size: 40),
              title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: total != null
                  ? Text('${progress ?? 0} / $total chapters')
                  : null,
              onTap: () {
                final id = item['book_id'] ?? item['id'];
                if (id != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoryDetailScreen(bookId: id is int ? id : int.tryParse(id.toString()) ?? 0),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
