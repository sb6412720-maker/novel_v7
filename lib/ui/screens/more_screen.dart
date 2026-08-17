import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'support_screen.dart';
import 'achievements_screen.dart';
import 'reading_stats_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconBg = isDark ? Colors.grey[800]! : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            context,
            cardColor: cardColor,
            children: [
              _tile(
                context,
                icon: Icons.person_outline,
                iconBg: iconBg,
                title: 'Profile',
                textColor: textColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              _tile(
                context,
                icon: Icons.emoji_events_outlined,
                iconBg: iconBg,
                title: 'Achievements',
                textColor: textColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                ),
              ),
              _tile(
                context,
                icon: Icons.bar_chart_outlined,
                iconBg: iconBg,
                title: 'Reading Stats',
                textColor: textColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReadingStatsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            cardColor: cardColor,
            children: [
              _tile(
                context,
                icon: Icons.brightness_6_outlined,
                iconBg: iconBg,
                title: 'Dark Mode',
                textColor: textColor,
                trailing: Switch(
                  value: ThemeController.instance.isDark,
                  onChanged: (v) => ThemeController.instance.toggle(),
                ),
              ),
              _tile(
                context,
                icon: Icons.help_outline,
                iconBg: iconBg,
                title: 'Support',
                textColor: textColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            cardColor: cardColor,
            children: [
              _tile(
                context,
                icon: Icons.logout,
                iconBg: iconBg,
                title: 'Sign out',
                textColor: Colors.redAccent,
                onTap: () async {
                  await AuthService.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required Color cardColor, required List<Widget> children}) {
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required String title,
    required Color textColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: textColor),
      ),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
