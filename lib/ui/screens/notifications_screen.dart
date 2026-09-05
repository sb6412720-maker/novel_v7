import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'story_detail_screen.dart';

/// Bell icon screen:
/// - Activity: likes / comments / reviews / follows / saves / support replies
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
  late Future<List<Map<String, dynamic>>> _activityFuture;
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
    _activityFuture = widget.apiService.fetchNotifications();
    _adminFuture = widget.apiService.fetchAdminNotifications();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_activityFuture, _adminFuture]);
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
      case 'support_reply':
        return Icons.support_agent;
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

  void _openSupportReply(Map<String, dynamic> n) {
    final title = (n['title'] ?? 'Support reply').toString();
    final message = (n['message'] ?? '').toString();
    final when = (n['created_at'] ?? '').toString();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent, color: AppTheme.brand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (when.isNotEmpty)
                  Text(
                    when,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  message.isEmpty ? 'No message body.' : message,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: isDark ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _coverOrIcon(Map<String, dynamic> n, String type) {
    final cover = (n['cover_path'] ?? n['actor_photo'] ?? '').toString();
    if (cover.isNotEmpty) {
      final url = widget.apiService.resolveAssetUrl(cover);
      return CircleAvatar(
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: null,
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
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Icon(Icons.notifications_none, size: 48, color: AppTheme.muted),
                const SizedBox(height: 12),
                Text(
                  emptyTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                  child: Text(
                    emptyBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted),
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
              final isSupport = type.toLowerCase() == 'support_reply';
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
                trailing: (bookId > 0 || isSupport)
                    ? const Icon(Icons.chevron_right, size: 20)
                    : null,
                onTap: () {
                  if (isSupport) {
                    _openSupportReply(n);
                  } else if (bookId > 0) {
                    _openBook(n);
                  } else if (message.isNotEmpty) {
                    _openSupportReply(n);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.brand,
          unselectedLabelColor: isDark ? Colors.white70 : Colors.grey,
          indicatorColor: AppTheme.brand,
          tabs: const [
            Tab(text: 'Activity'),
            Tab(text: 'Admin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _list(
            future: _activityFuture,
            emptyTitle: 'No activity yet',
            emptyBody:
                'Likes, comments, follows, and support replies will appear here.',
          ),
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
