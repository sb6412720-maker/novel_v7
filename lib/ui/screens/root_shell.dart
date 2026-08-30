import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import 'discover_screen.dart';
import 'library_screen.dart';
import 'login_screen.dart';
import 'onboarding_profile_screen.dart';
import 'more_screen.dart';
import 'notifications_screen.dart';
import 'write_screen.dart';

/// App shell.
///
/// **Read access without login:** Discover (and public story pages) work with no
/// account. Library / Write / Notifications / personal profile require sign-in.
/// Guest sign-in still available for light personalization.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  late final AuthService _authService = AuthService(apiService: _apiService);
  int _selectedIndex = 1; // Discover by default for read-only visitors
  AppBootstrap? _bootstrap;
  bool _loading = true;
  String _contentVersion = '';
  Timer? _syncTimer;
  AuthSession? _session;
  bool _showLoginOverlay = false;

  bool get _isAuthenticated => _session != null && !_session!.isGuest;
  bool get _isGuestSession => _session != null && _session!.isGuest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapApp();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _pollContentVersion(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pollContentVersion());
      unawaited(_loadBootstrap(showLoading: false));
    }
  }

  /// Background refresh — never set _bootstrap to null / empty loading shell.
  Future<void> _softRefresh() async {
    try {
      final version = await _apiService.fetchContentVersion();
      if (!mounted) return;
      if (version.isNotEmpty && version != _contentVersion) {
        await _loadBootstrap(showLoading: false);
      }
    } catch (_) {
      // keep current screen data
    }
  }

  Future<void> _bootstrapApp() async {
    // Restore token session first — login gate if none.
    try {
      final restored = await _authService.restoreSession();
      if (mounted && restored != null) {
        setState(() {
          _session = restored;
          _showLoginOverlay = false;
        });
      } else if (mounted) {
        setState(() {
          _session = null;
          _showLoginOverlay = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _session = null;
          _showLoginOverlay = true;
        });
      }
    }
    // Keep spinner until network bootstrap finishes (no half-loaded UI).
    if (mounted) setState(() => _loading = true);
    // Warm disk cache in background only — do not show UI yet
    unawaited(_apiService.loadDiskBootstrap());
    await _loadBootstrap(showLoading: true);
  }

  Future<void> _loadBootstrap({bool showLoading = true}) async {
    final isFirst = _bootstrap == null;
    if (mounted && showLoading && isFirst) {
      setState(() => _loading = true);
    }
    try {
      final results = await Future.wait<dynamic>([
        _apiService.fetchBootstrap(),
        _apiService.fetchContentVersion(),
      ]);
      final bootstrap = results[0] as AppBootstrap;
      final version = results[1] as String;
      if (!mounted) return;
      // Never replace a full home with an empty shell
      final hasData =
          bootstrap.discoverBooks.isNotEmpty ||
          bootstrap.recentlyUpdated.isNotEmpty;
      setState(() {
        if (hasData || _bootstrap == null) {
          _bootstrap = bootstrap;
        }
        if (version.isNotEmpty) _contentVersion = version;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pollContentVersion() async {
    if (_loading || _bootstrap == null) return;
    final latestVersion = await _apiService.fetchContentVersion();
    if (!mounted || latestVersion.isEmpty || latestVersion == _contentVersion) {
      return;
    }
    await _loadBootstrap(showLoading: false);
  }

  Future<void> _continueLogin(
    String method, {
    String? email,
    String? password,
    String? mode,
    String? displayName,
    String? username,
  }) async {
    try {
      final AuthSession session;
      if (method == 'google') {
        session = await _authService.signInWithGoogle();
      } else if (method == 'email') {
        session = await _authService.signInWithEmail(
          email ?? username ?? '',
          password: password ?? '',
          mode: mode ?? 'login',
          displayName: displayName,
        );
      } else {
        session = await _authService.signInAsGuest();
      }
      if (!mounted) return;
      setState(() {
        _session = session;
      });
      // First-time users only: complete profile BEFORE Discover (cannot skip).
      // Never again from More / Profile.
      if (!session.isGuest) {
        final needsProfile = await _needsCompleteProfile(session);
        if (!mounted) return;
        if (needsProfile) {
          await _showOnboardingBlocking(session);
          if (!mounted) return;
          final still = await _needsCompleteProfile(session);
          if (!mounted) return;
          if (still) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please complete your profile to continue')),
            );
            return;
          }
        } else {
          // Already complete (local or server) — keep flags warm
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_profileDoneKey(session), true);
            await prefs.setBool('profile_complete_local_done', true);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() {
        _showLoginOverlay = false;
      });
      await _loadBootstrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            session.isGoogle
                ? 'Signed in as ${session.displayName}'
                : session.isGuest
                ? 'Continuing as guest (device-limited session)'
                : 'Signed in with ${session.email}',
          ),
        ),
      );
    } on AuthBlockedException catch (e) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _showLoginOverlay = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor:
              msg.toLowerCase().contains('banned') ||
                  msg.toLowerCase().contains('suspended')
              ? Colors.red.shade700
              : null,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  bool _isProfileCompleteFlag(dynamic completeRaw) {
    return completeRaw == true ||
        completeRaw == 1 ||
        completeRaw == '1' ||
        completeRaw == 'true' ||
        completeRaw == 'True';
  }

  String _profileDoneKey(AuthSession session) {
    final id = session.id?.toString() ?? session.email ?? 'unknown';
    return 'profile_complete_local_$id';
  }

  Future<bool> _needsCompleteProfile(AuthSession session) async {
    if (session.isGuest) return false;
    // Device cache: once completed on this install, never show again (More/Profile included)
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_profileDoneKey(session)) == true ||
          prefs.getBool('profile_complete_local_done') == true) {
        return false;
      }
    } catch (_) {}
    try {
      final me = await _apiService.fetchMe();
      final done = _isProfileCompleteFlag(me['profile_complete']);
      if (done) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_profileDoneKey(session), true);
        } catch (_) {}
        return false;
      }
      return true;
    } catch (_) {
      // Do not re-prompt from More/Profile when /api/me fails
      return false;
    }
  }

  Future<void> _showOnboardingBlocking(AuthSession session) async {
    try {
      final me = await _apiService.fetchMe();
      final name = (me['display_name'] ?? '').toString().trim();
      final display = name.isNotEmpty && name.toLowerCase() != 'reader'
          ? name
          : session.displayName.toString().trim();
      final photo =
          (me['photo_url'] ?? me['avatar_url'] ?? session.photoUrl ?? '')
              .toString();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PopScope(
            canPop: false,
            child: OnboardingProfileScreen(
              apiService: _apiService,
              initialDisplayName:
                  display.toLowerCase() == 'reader' ? '' : display,
              initialPhotoUrl: photo,
              onDone: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        ),
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_profileDoneKey(session), true);
      } catch (_) {}
      try {
        await _apiService.updateMe({'profile_complete': true});
      } catch (_) {}
      final refreshed = await _authService.refreshSessionFromServer();
      if (mounted && refreshed != null) {
        setState(() => _session = refreshed);
      }
      unawaited(_loadBootstrap(showLoading: false));
    } catch (_) {}
  }

  Future<void> _maybeShowOnboarding(AuthSession session) async {
    // Intentionally empty — complete profile only runs once in _continueLogin
    // before Discover. Never from More / Profile / tab switches.
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    setState(() {
      _session = null;
      _selectedIndex = 1;
      _showLoginOverlay = true;
    });
    await _loadBootstrap();
  }

  void _requireAuth({int? afterLoginIndex}) {
    setState(() {
      _showLoginOverlay = true;
      if (afterLoginIndex != null) _selectedIndex = afterLoginIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _bootstrap == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    // Explicit login overlay (when user taps a gated tab)
    if (_showLoginOverlay && !_isAuthenticated) {
      return LoginScreen(
        onContinue: _continueLogin,
        onSkipAsReader: () {
          _continueLogin('guest');
        },
      );
    }

    if (_bootstrap == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load stories. Check connection.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadBootstrap,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _requireAuth(),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }

    final pages = <Widget>[
      // Library — requires auth
      _isAuthenticated
          ? LibraryScreen(
              data: _bootstrap!,
              apiService: _apiService,
              onOpenDiscover: () => setState(() => _selectedIndex = 1),
            )
          : _AuthGate(
              title: 'Your Library',
              message:
                  'Sign in to see Current Reads, History, and Reading Lists. You can still browse Discover without an account.',
              onSignIn: () => _requireAuth(afterLoginIndex: 0),
              onBrowse: () => setState(() => _selectedIndex = 1),
            ),
      DiscoverScreen(data: _bootstrap!, apiService: _apiService),
      // Write — requires auth
      _isAuthenticated
          ? WriteScreen(data: _bootstrap!, apiService: _apiService)
          : _AuthGate(
              title: 'Write',
              message: 'Sign in to create and manage your stories.',
              onSignIn: () => _requireAuth(afterLoginIndex: 2),
              onBrowse: () => setState(() => _selectedIndex = 1),
            ),
      _isAuthenticated
          ? NotificationsScreen(
              data: _bootstrap!,
              apiService: _apiService,
              onOpenDiscover: () => setState(() => _selectedIndex = 1),
            )
          : _AuthGate(
              title: 'Notifications',
              message: 'Sign in to receive updates about stories you follow.',
              onSignIn: () => _requireAuth(afterLoginIndex: 3),
              onBrowse: () => setState(() => _selectedIndex = 1),
            ),
      _isAuthenticated
          ? MoreScreen(
              data: _bootstrap!,
              apiService: _apiService,
              onSignOut: _signOut,
              session: _session!,
            )
          : _AuthGate(
              title: 'Account',
              message: 'Sign in for profile, settings, and saved progress.',
              onSignIn: () => _requireAuth(afterLoginIndex: 4),
              onBrowse: () => setState(() => _selectedIndex = 1),
            ),
    ];

    // IndexedStack keeps Discover/Library state alive when switching tabs
    // (fixes empty Discover after leaving a story/comments).
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        height: 76,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        indicatorColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2C)
            : Colors.transparent,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          // Guests and logged-out users: Discover only; other tabs need real account
          if (!_isAuthenticated && value != 1) {
            if (_isGuestSession) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Guest can only read books. Sign in to use this feature.'),
                ),
              );
            }
            _requireAuth(afterLoginIndex: value);
            return;
          }
          setState(() => _selectedIndex = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit),
            label: 'Write',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            selectedIcon: Icon(Icons.menu),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.title,
    required this.message,
    required this.onSignIn,
    required this.onBrowse,
  });

  final String title;
  final String message;
  final VoidCallback onSignIn;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
            TextButton(
              onPressed: onBrowse,
              child: const Text('Continue reading on Discover'),
            ),
          ],
        ),
      ),
    );
  }
}
