import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';
import 'email_verify_screen.dart';

/// Create Account — purple theme matching login / home UI.
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
  bool _agreed = false;
  DateTime? _birthDate;
  String? _gender;
  String? _country;
  File? _photo;
  String _photoUrl = '';

  static const _purple = Color(0xFF6C3CE1);
  static const _genders = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];
  static const _countries = [
    'United States',
    'United Kingdom',
    'India',
    'Sri Lanka',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Other',
  ];

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

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _photo = File(x.path));
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
      final path =
          (res['path'] ?? res['url'] ?? res['photo_url'] ?? '').toString();
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to Privacy Policy and Terms')),
      );
      return;
    }
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your birthday')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final upPhoto = await _upload(_photo);
      if (upPhoto != null) _photoUrl = upPhoto;

      final result = await _api.registerAccount({
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'display_name': _nameCtrl.text.trim(),
        'username': _userCtrl.text.trim().replaceAll('@', ''),
        if (_photoUrl.isNotEmpty) 'photo_url': _photoUrl,
        if (_gender != null) 'gender': _gender,
        if (_country != null) 'country': _country,
        'birth_date':
            '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
        'profile_complete': true,
      });

      // Optional email verify flow
      final needsVerify = result['needs_verification'] == true;
      if (needsVerify && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EmailVerifyScreen(
              apiService: _api,
              email: _emailCtrl.text.trim(),
            ),
          ),
        );
      }

      await widget.onContinue(
        'email',
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        mode: 'login',
        displayName: _nameCtrl.text.trim(),
        username: _userCtrl.text.trim().replaceAll('@', ''),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await widget.onContinue('google');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _deco({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _purple, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F5FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8E4F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _purple, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _busy ? null : _pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFFEDE9FE),
                          backgroundImage:
                              _photo != null ? FileImage(_photo!) : null,
                          child: _photo == null
                              ? const Icon(Icons.person, color: _purple, size: 32)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: _purple,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign up and start your journey with us',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _deco(
                          label: 'Name',
                          hint: 'Enter your full name',
                          icon: Icons.person_outline,
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _userCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _deco(
                          label: 'User ID',
                          hint: 'Choose a user ID',
                          icon: Icons.alternate_email,
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim().replaceAll('@', '');
                          if (t.length < 3) return 'At least 3 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _deco(
                          label: 'Email',
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (!t.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickBirthday,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: _deco(
                            label: 'Birthday',
                            hint: 'Select your birthday',
                            icon: Icons.calendar_today_outlined,
                            suffix: const Icon(Icons.event, color: _purple),
                          ),
                          child: Text(
                            _birthDate == null
                                ? 'Select your birthday'
                                : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: _birthDate == null
                                  ? Colors.grey.shade600
                                  : const Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        isExpanded: true,
                        decoration: _deco(
                          label: 'Sex',
                          hint: 'Select your sex',
                          icon: Icons.wc_outlined,
                        ),
                        items: _genders
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _gender = v),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Select sex' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _country,
                        isExpanded: true,
                        decoration: _deco(
                          label: 'Country',
                          hint: 'Select your country',
                          icon: Icons.public_outlined,
                        ),
                        items: _countries
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _country = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        decoration: _deco(
                          label: 'New Password',
                          hint: 'Create a new password',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass2Ctrl,
                        obscureText: _obscure2,
                        decoration: _deco(
                          label: 'Re-enter Password',
                          hint: 'Re-enter your password',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure2
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _obscure2 = !_obscure2),
                          ),
                        ),
                        validator: (v) {
                          if (v != _passCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            activeColor: _purple,
                            onChanged: (v) =>
                                setState(() => _agreed = v ?? false),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  children: const [
                                    TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                        color: _purple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: TextStyle(
                                        color: _purple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _purple,
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
                                  'Sign Up',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or continue with',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _google,
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _purple,
                            side: const BorderSide(color: Color(0xFFE8E4F5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                color: _purple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
