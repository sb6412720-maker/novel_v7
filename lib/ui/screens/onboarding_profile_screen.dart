import 'package:flutter/material.dart';

import '../../data/services/api_service.dart';

/// Shown once after first Google/email sign-in until profile basics are filled.
class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({
    super.key,
    required this.apiService,
    this.initialDisplayName = '',
    this.initialPhotoUrl = '',
    required this.onDone,
  });

  final ApiService apiService;
  final String initialDisplayName;
  final String initialPhotoUrl;
  final VoidCallback onDone;

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  String? _gender;
  DateTime? _birthDate;
  bool _saving = false;

  static const _genders = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialDisplayName);
    _bioCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 13, now.month, now.day),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.apiService.updateMyProfile({
        'display_name': name,
        'bio': _bioCtrl.text.trim(),
        if (_gender != null) 'gender': _gender,
        if (_birthDate != null)
          'birth_date':
              '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
        'profile_complete': true,
        if (widget.initialPhotoUrl.isNotEmpty)
          'photo_url': widget.initialPhotoUrl,
      });
      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      // Cold start / timeout: still continue — profile can sync later
      final msg = e.toString().toLowerCase();
      final isTimeout = msg.contains('timeout') || msg.contains('timed out');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTimeout
                ? 'Server is waking up — your name was kept. You can edit profile later.'
                : 'Could not save profile: $e',
          ),
        ),
      );
      if (isTimeout) widget.onDone();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text(
              'Complete your profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Readers and authors see this on your profile.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 28),
            if (widget.initialPhotoUrl.isNotEmpty)
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(
                    widget.apiService.resolveAssetUrl(widget.initialPhotoUrl),
                  ),
                ),
              ),
            if (widget.initialPhotoUrl.isNotEmpty) const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display name *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'A short intro about you',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownMenu<String>(
              initialSelection: _gender,
              label: const Text('Gender'),
              dropdownMenuEntries: _genders
                  .map((g) => DropdownMenuEntry<String>(value: g, label: g))
                  .toList(),
              onSelected: (v) => setState(() => _gender = v),
              expandedInsets: EdgeInsets.zero,
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _birthDate == null
                    ? 'Birth date (optional)'
                    : 'Birth date: ${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickBirthDate,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save and continue'),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : widget.onDone,
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
