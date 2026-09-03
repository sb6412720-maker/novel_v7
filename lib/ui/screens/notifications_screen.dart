import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'story_detail_screen.dart';

/// Bell icon screen:
/// - Activity: other users liked / commented / reviewed / followed / saved your work
/// - Admin: system announcements
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.apiService,
    this.onOpenDiscover,
    this.data,
  });

  final ApiService apiService;
  final VoidCallback? onOpenDiscover;
  final dynamic data;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _adminFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    _adminFuture = widget.apiService.fetchAdminNotifications();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _adminFuture;
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'like':
        return Icons.favorite;
      case 'review':
        return Icons.star;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'follow':
        return Icons.person_add_alt_1;
      case 'save':
        return Icons.bookmark;
      case 'share':
        return Icons.ios_share;
      case 'admin':
      case 'system':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications;
    }
  }

  void _openBook(Map<String, dynamic> n) {
    final bookId = (n['book_id'] as num?)?.toInt() ?? 0;
    if (bookId <= 0) return;
    final cover = (n['cover_path'] ?? '').toString();
    final title = (n['title'] ?? 'Story').toString();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailScreen(
          apiService: widget.apiService,
          book: BookDetailModel(
            id: bookId,
            title: title,
            author: (n['actor_name'] ?? '').toString(),
            description: (n['message'] ?? '').toString(),
            statusText: '',
            rating: 0,
            genre: '',
            cta: 'Read Now',
            coverPath: cover,
          ),
        ),
      ),
    );
  }

  Widget _coverOrIcon(Map<String, dynamic> n, String type) {
    final cover = (n['cover_path'] ?? '').toString();
    if (cover.isNotEmpty) {
      final url = widget.apiService.resolveAssetUrl(cover);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 48,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            backgroundColor: AppTheme.brand.withValues(alpha: 0.12),
            child: Icon(_iconFor(type), color: AppTheme.brand, size: 20),
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: AppTheme.brand.withValues(alpha: 0.12),
      child: Icon(_iconFor(type), color: AppTheme.brand, size: 20),
    );
  }

  Widget _list({
    required Future<List<Map<String, dynamic>>> future,
    required String emptyTitle,
    required String emptyBody,
  }) {
    return RefreshIndicator(
      color: AppTheme.brand,
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Icon(
                  Icons.notifications_none,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    emptyTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    emptyBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = rows[i];
              final type = (n['type'] ?? n['tab'] ?? '').toString();
              final title = (n['title'] ?? n['message'] ?? 'Update').toString();
              final message = (n['message'] ?? '').toString();
              final when = (n['created_at'] ?? '').toString();
              final bookId = (n['book_id'] as num?)?.toInt() ?? 0;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: _coverOrIcon(n, type),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  [
                    if (message.isNotEmpty && message != title) message,
                    if (when.isNotEmpty) when,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: bookId > 0
                    ? const Icon(Icons.chevron_right, size: 20)
                    : null,
                onTap: bookId > 0 ? () => _openBook(n) : null,
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.brand,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.brand,
          tabs: const [Tab(text: 'Admin')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _list(
            future: _adminFuture,
            emptyTitle: 'No admin notices',
            emptyBody: 'System and admin announcements will appear here.',
          ),
        ],
      ),
    );
  }
}
