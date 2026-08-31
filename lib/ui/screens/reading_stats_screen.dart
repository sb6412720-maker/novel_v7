import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';

/// Reading Stats: minutes per weekday from tracked chapter reading time.
class ReadingStatsScreen extends StatefulWidget {
  const ReadingStatsScreen({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  @override
  State<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends State<ReadingStatsScreen> {
  /// Minutes for last 7 days Mon..Sun order of current week
  List<double> _minutes = List<double>.filled(7, 0);
  final _labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('reading_seconds_by_day_v1') ?? '{}';
      final map = Map<String, dynamic>.from((jsonDecode(raw) as Map?) ?? {});
      final now = DateTime.now();
      // Start of week (Monday)
      final monday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final mins = <double>[];
      for (var i = 0; i < 7; i++) {
        final d = monday.add(Duration(days: i));
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final sec = (map[key] as num?)?.toInt() ?? 0;
        mins.add(sec / 60.0);
      }
      if (mounted) {
        setState(() {
          _minutes = mins;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final maxM = _minutes.fold<double>(0, (a, b) => a > b ? a : b);
    final scale = maxM <= 0 ? 1.0 : maxM;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reading Stats'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.menu_book_rounded,
                        color: const Color(0xFF9B59B6),
                        label: 'CHAPTERS READ',
                        value: '${profile.chaptersRead}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        icon: Icons.local_fire_department_outlined,
                        color: const Color(0xFFE85D4C),
                        label: 'DAY STREAK',
                        value: '${profile.dayStreak}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _statCard(
                  icon: Icons.timer_outlined,
                  color: AppTheme.brand,
                  label: 'MINUTES THIS WEEK',
                  value: _minutes.fold<double>(0, (a, b) => a + b).round().toString(),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Reading time this week',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Y axis: minutes · X axis: day of week',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A8F98)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final h = 8.0 + (_minutes[i] / scale) * 140.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _minutes[i] < 1
                                    ? '0'
                                    : _minutes[i].round().toString(),
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: h,
                                decoration: BoxDecoration(
                                  color: AppTheme.brand.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _labels[i],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
