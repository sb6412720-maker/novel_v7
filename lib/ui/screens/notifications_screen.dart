import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

/// Bell tab:
/// - Notifications: what *others* did on your stories/profile
/// - My Activity: likes / reviews / follows / saves *by me*
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
  late TabController _tabs;
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  late Future<List<Map<String, dynamic>>> _activityFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _notificationsFuture = widget.apiService.fetchNotifications();
    _activityFuture = widget.apiService.fetchMyActivity();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _notificationsFuture = widget.apiService.fetchNotifications();
      _activityFuture = widget.apiService.fetchMyActivity();
    });
    await Future.wait([_notificationsFuture, _activityFuture]);
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
      case 'bookmark':
        return Icons.bookmark;
      case 'share':
        return Icons.ios_share;
      case 'read':
        return Icons.menu_book;
      default:
        return Icons.notifications;
    }
  }

  Widget _list({
    required Future<List<Map<String, dynamic>>> future,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    return RefreshIndicator(
      color: AppTheme.brand,
      onRefresh: _reload,
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
                const SizedBox(height: 120),
                const Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    emptyTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      emptySubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = rows[i];
              final type = (n['type'] ?? n['tab'] ?? n['action'] ?? '').toString();
              final title = (n['title'] ?? n['message'] ?? n['body'] ?? 'Update').toString();
              final message = (n['message'] ?? n['body'] ?? '').toString();
              final when = (n['created_at'] ?? n['time'] ?? '').toString();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.brand.withValues(alpha: 0.12),
                  child: Icon(_iconFor(type), color: AppTheme.brand, size: 20),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    if (message.isNotEmpty && message != title) message,
                    when,
                  ].where((s) => s.toString().isNotEmpty).join(' · '),
                ),
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
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.brand,
          tabs: const [
            Tab(text: 'Notifications'),
            Tab(text: 'My Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _list(
            future: _notificationsFuture,
            emptyTitle: 'No notifications yet',
            emptySubtitle:
                'When people like, comment, review, save or follow you, it shows here.',
          ),
          _list(
            future: _activityFuture,
            emptyTitle: 'No activity yet',
            emptySubtitle:
                'Likes, reviews, follows and saves you make will appear here.',
          ),
        ],
      ),
    );
  }
}
