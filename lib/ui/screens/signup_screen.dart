import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';
import 'email_verify_screen.dart';

/// Full registration form matching product requirements.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    super.key,
    required this.onContinue,
    this.apiService,
  });

  final Future<void> Function(
    String method, {
    String? email,
    String? password,
    String? mode,
    String? displayName,
    String? username,
  }) onContinue;

  final ApiService? apiService;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _obscure = true;
  bool _obscure2 = true;
  bool _busy = false;
  File? _photo;
  File? _cover;
  String _photoUrl = '';
  String _coverUrl = '';

  ApiService get _api => widget.apiService ?? ApiService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    final p = v ?? '';
    if (p.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(p)) return 'Include a letter';
    if (!RegExp(r'[0-9]').hasMatch(p)) return 'Include a number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(p)) return 'Include a symbol';
    return null;
  }

  Future<void> _pick({required bool cover}) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: cover ? 1600 : 800,
      maxHeight: cover ? 900 : 800,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      if (cover) {
        _cover = File(x.path);
      } else {
        _photo = File(x.path);
      }
    });
  }

  Future<String?> _upload(File? file) async {
    if (file == null) return null;
    try {
      final bytes = await file.readAsBytes();
      final name = file.path.split(RegExp(r'[\\/]')).last;
      final res = await _api.uploadUserImage(
        bytes,
        name.isEmpty ? 'photo.jpg' : name,
      );
      final path = (res['path'] ?? res['url'] ?? res['photo_url'] ?? '').toString();
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final upPhoto = await _upload(_photo);
      final upCover = await _upload(_cover);
      if (upPhoto != null) _photoUrl = upPhoto;
      if (upCover != null) _coverUrl = upCover;

      final result = await _api.registerAccount({
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'display_name': _nameCtrl.text.trim(),
        'username': _userCtrl.text.trim().replaceAll('@', ''),
        if (_photoUrl.isNotEmpty) 'photo_url': _photoUrl,
        if (_coverUrl.isNotEmpty) 'cover_url': _coverUrl,
      });

      if (!mounted) return;
      final email = _emailCtrl.text.trim();
      final devToken = (result['dev_token'] ?? '').toString();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EmailVerifyScreen(
            email: email,
            apiService: _api,
            initialDevToken: devToken.isEmpty ? null : devToken,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await widget.onContinue('google');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create account'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () => _pick(cover: false),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFFE8EEF9),
                          backgroundImage:
                              _photo != null ? FileImage(_photo!) : null,
                          child: _photo == null
                              ? const Icon(Icons.add_a_photo_outlined, size: 28)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.brand,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Profile picture (optional)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _pick(cover: true),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                      image: _cover != null
                          ? DecorationImage(
                              image: FileImage(_cover!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _cover == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, color: Colors.black45),
                              SizedBox(height: 4),
                              Text(
                                'Cover photo (optional)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixText: '@',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim().replaceAll('@', '');
                    if (s.length < 3) return 'At least 3 characters';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(s)) {
                      return 'Letters, numbers, underscore only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
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
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: '8+ chars with letters, numbers & symbol',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass2Ctrl,
                  obscureText: _obscure2,
                  decoration: InputDecoration(
                    labelText: 'Re-enter password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure2
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create account',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
