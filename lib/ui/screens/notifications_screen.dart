import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

/// Bell tab: what *others* did on your stories/profile.
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

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.apiService.fetchNotifications();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.apiService.fetchNotifications();
    });
    await _future;
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
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No notifications yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'When people like, comment, review, save or follow you, it shows here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.muted),
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
                    [if (message.isNotEmpty && message != title) message, when]
                        .where((s) => s.toString().isNotEmpty)
                        .join(' · '),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
