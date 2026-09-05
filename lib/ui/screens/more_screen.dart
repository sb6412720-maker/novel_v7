import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import 'more_settings_pages.dart';
import 'profile_screen.dart';
import 'reading_stats_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.data,
    required this.apiService,
    required this.session,
    required this.onSignOut,
  });
  final AppBootstrap data;
  final ApiService apiService;
  final AuthSession session;
  final Future<void> Function() onSignOut;
  static const _purple = Color(0xFF8B5CF6);

  ProfileModel _profile() {
    final p = data.profile;
    return ProfileModel(
      id: session.id ?? p.id,
      displayName: session.displayName.isNotEmpty
          ? session.displayName
          : p.displayName,
      username: p.username,
      photoUrl: (session.photoUrl != null && session.photoUrl!.isNotEmpty)
          ? session.photoUrl!
          : p.photoUrl,
      coverUrl: p.coverUrl,
      following: p.following,
      followers: p.followers,
      blocked: p.blocked,
      chaptersRead: p.chaptersRead,
      socialKarma: p.socialKarma,
      dayStreak: p.dayStreak,
      readingLists: p.readingLists,
      isAuthor: p.isAuthor,
      bio: p.bio,
      gender: p.gender,
      birthDate: p.birthDate,
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          profile: _profile(),
          apiService: apiService,
          achievements: data.achievements,
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    if (await showSignOutConfirmDialog(context)) await onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = session.displayName.isNotEmpty
        ? session.displayName
        : (data.profile.displayName.isNotEmpty
              ? data.profile.displayName
              : 'Reader');
    final email = session.email.isNotEmpty ? session.email : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _card(isDark),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _openProfile(context),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark
                      ? Colors.white24
                      : const Color(0xFFEDE9FE),
                  backgroundImage: _profile().photoUrl.trim().isNotEmpty
                      ? NetworkImage(
                          apiService.resolveAssetUrl(_profile().photoUrl),
                        )
                      : null,
                  child: _profile().photoUrl.trim().isEmpty
                      ? Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openProfile(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionLabel('Appearance'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _card(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Light / Dark mode',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: ThemeController.instance,
                builder: (context, _) {
                  final mode = ThemeController.instance.mode;
                  return Row(
                    children: [
                      _themeChip(
                        'Light',
                        mode == ThemeMode.light,
                        () => ThemeController.instance.setMode(ThemeMode.light),
                      ),
                      const SizedBox(width: 8),
                      _themeChip(
                        'Dark',
                        mode == ThemeMode.dark,
                        () => ThemeController.instance.setMode(ThemeMode.dark),
                      ),
                      const SizedBox(width: 8),
                      _themeChip(
                        'System',
                        mode == ThemeMode.system,
                        () =>
                            ThemeController.instance.setMode(ThemeMode.system),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionLabel('Profile'),
        _menuCard(isDark, [
          _Item(Icons.bar_chart_rounded, 'Reading Stats', () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReadingStatsScreen(
                  profile: _profile(),
                  apiService: apiService,
                ),
              ),
            );
          }),
        ]),
        const SizedBox(height: 12),
        _sectionLabel('Support'),
        _menuCard(isDark, [
          _Item(
            Icons.help_outline,
            'Help Center',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HelpCenterScreen(apiService: apiService),
              ),
            ),
          ),
          _Item(
            Icons.mail_outline,
            'Contact Us',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ContactUsScreen(apiService: apiService, email: email),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _sectionLabel('Settings'),
        _menuCard(isDark, [
          _Item(
            Icons.notifications_none,
            'Notifications',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    NotificationSettingsScreen(apiService: apiService),
              ),
            ),
          ),
          _Item(
            Icons.language,
            'App Language',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AppLanguageScreen(apiService: apiService),
              ),
            ),
          ),
          _Item(
            Icons.favorite_border,
            'Favourite Genres',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FavouriteGenresScreen(apiService: apiService),
              ),
            ),
          ),
          _Item(
            Icons.warning_amber_outlined,
            'Content Warnings',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ContentWarningsScreen(apiService: apiService),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _sectionLabel('Legal'),
        _menuCard(isDark, [
          _Item(
            Icons.cookie_outlined,
            'Manage Cookie Preferences',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CookiePreferencesScreen(apiService: apiService),
              ),
            ),
          ),
          _Item(
            Icons.description_outlined,
            'Terms of Service',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LegalTextScreen(
                  title: 'Terms of Service',
                  sections: termsSections(),
                ),
              ),
            ),
          ),
          _Item(
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LegalTextScreen(
                  title: 'Privacy Policy',
                  sections: privacySections(),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _sectionLabel('Change Accounts'),
        _menuCard(isDark, [
          _Item(
            Icons.logout,
            'Sign Out',
            () => _signOut(context),
            danger: true,
          ),
        ]),
      ],
    );
  }

  BoxDecoration _card(bool isDark) => BoxDecoration(
    color: isDark ? const Color(0xFF121212) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isDark ? Colors.white24 : const Color(0xFFE9E4F5),
    ),
  );
  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Builder(
      builder: (context) => Text(
        t,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : Colors.grey.shade600,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
  Widget _themeChip(String label, bool selected, VoidCallback onTap) =>
      Expanded(
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _purple : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? _purple
                        : (isDark ? Colors.white24 : const Color(0xFFE9E4F5)),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white : AppTheme.ink),
                  ),
                ),
              ),
            );
          },
        ),
      );
  Widget _menuCard(bool isDark, List<_Item> items) => Container(
    decoration: _card(isDark),
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          ListTile(
            leading: Icon(
              items[i].icon,
              color: items[i].danger ? const Color(0xFFE53935) : _purple,
            ),
            title: Text(
              items[i].label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: items[i].danger ? const Color(0xFFE53935) : null,
              ),
            ),
            trailing: items[i].danger
                ? null
                : const Icon(Icons.chevron_right, size: 20),
            onTap: items[i].onTap,
          ),
          if (i < items.length - 1)
            Divider(
              height: 1,
              indent: 56,
              color: isDark ? Colors.white12 : const Color(0xFFE9E4F5),
            ),
        ],
      ],
    ),
  );
}

class _Item {
  const _Item(this.icon, this.label, this.onTap, {this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}
