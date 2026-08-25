import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'signup_screen.dart';

/// Welcome / Sign in screen (professional auth entry).
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onContinue,
    this.onSkipAsReader,
  });

  final Future<void> Function(
    String method, {
    String? email,
    String? password,
    String? mode,
    String? displayName,
  }) onContinue;

  final VoidCallback? onSkipAsReader;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEmailLogin() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscure = true;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sign in',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Welcome back to NovelHub',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty || !s.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setModal(() => obscure = !obscure),
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? '').length < 6) {
                            return 'At least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: () {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            Navigator.of(context).pop({
                              'email': emailCtrl.text.trim(),
                              'password': passCtrl.text,
                              'mode': 'login',
                            });
                          },
                          child: const Text('Sign in'),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Future.microtask(() {
                            if (!mounted) return;
                            Navigator.of(this.context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SignUpScreen(
                                  onContinue: widget.onContinue,
                                ),
                              ),
                            );
                          });
                        },
                        child: const Text('New here? Create an account'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    emailCtrl.dispose();
    passCtrl.dispose();
    if (result == null || !mounted) return;

    await _run(
      () => widget.onContinue(
        'email',
        email: result['email'],
        password: result['password'],
        mode: result['mode'] ?? 'login',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDF9F3), Color(0xFFEAF5F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'NovelHub',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Discover millions of free books',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF525252),
                          ),
                    ),
                    const SizedBox(height: 40),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: CircularProgressIndicator(),
                      ),
                    _AuthButton(
                      icon: Icons.g_mobiledata_rounded,
                      label: 'Continue with Google',
                      onPressed: _busy
                          ? null
                          : () => _run(() => widget.onContinue('google')),
                    ),
                    const SizedBox(height: 12),
                    _AuthButton(
                      icon: Icons.email_outlined,
                      label: 'Sign in with email',
                      onPressed: _busy ? null : _openEmailLogin,
                    ),
                    const SizedBox(height: 12),
                    _AuthButton(
                      icon: Icons.person_outline,
                      label: 'Continue as Guest',
                      onPressed: _busy
                          ? null
                          : () => _run(() => widget.onContinue('guest')),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SignUpScreen(
                                        onContinue: widget.onContinue,
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Sign up'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.ink,
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF525252),
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
