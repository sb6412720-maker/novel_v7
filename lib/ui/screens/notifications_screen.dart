import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

/// Bottom-nav notifications:
/// - Activity: other users liked/commented/reviewed/followed you
/// - Admin: system / admin announcements from notifications table
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
      case 'admin':
      case 'system':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications;
    }
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
                Icon(Icons.notifications_none, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    emptyTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = rows[i];
              final type = (n['type'] ?? n['tab'] ?? '').toString();
              final title = (n['title'] ?? n['message'] ?? 'Update').toString();
              final message = (n['message'] ?? '').toString();
              final when = (n['created_at'] ?? '').toString();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.brand.withValues(alpha: 0.12),
                  child: Icon(_iconFor(type), color: AppTheme.brand, size: 20),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    if (message.isNotEmpty && message != title) message,
                    if (when.isNotEmpty) when,
                  ].join(' · '),
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
          unselectedLabelColor: Colors.grey,
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
                'When people like, comment, review, save or follow you, it shows here.',
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
