import 'package:flutter/material.dart';
import '../../data/services/api_service.dart';

class MorePageChrome {
  static const Color purple = Color(0xFF8B5CF6);
  static const Color muted = Color(0xFF6B6575);
  static Color mutedOf(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Colors.white70 : muted;
  }

  static Color textOf(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Colors.white : const Color(0xFF1A1A1A);
  }

  static BoxDecoration card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: dark ? const Color(0xFF121212) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dark ? Colors.white24 : const Color(0xFFE9E4F5),
      ),
    );
  }
}

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key, required this.apiService});
  final ApiService apiService;
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _query = '';

  static const Map<String, List<Map<String, String>>> _faq = {
    'Account & Login': [
      {
        'q': 'How do I sign in with Google?',
        'a':
            'On the login screen tap Continue with Google, choose your account, and complete the one-time profile form if this is your first visit. Next logins skip the form automatically.',
      },
      {
        'q': 'Why am I asked to complete my profile?',
        'a':
            'Only the first time you sign in with Google (or email). We store display name, birthday and preferences in the database so we never ask again on that account.',
      },
      {
        'q': 'How do I sign out?',
        'a':
            'Open the More tab → Change Accounts → Sign Out. Your reading progress stays linked to your account.',
      },
      {
        'q': 'Can I delete my account?',
        'a':
            'Contact support via Live Chat or Contact Us and request account deletion. An admin will process the request.',
      },
    ],
    'Reading': [
      {
        'q': 'How does reading progress work?',
        'a':
            'Progress is saved per chapter as you scroll and when you mark a story complete from Library. Resume opens the exact paragraph you left.',
      },
      {
        'q': 'How are reading stats calculated?',
        'a':
            'Chapters read, completed books and day streak come from your library activity stored on the server.',
      },
    ],
    'Writing & Stories': [
      {
        'q': 'How do I publish a story?',
        'a':
            'Open Write → Create Story, add chapters, then publish. Stories default to Published; three reports can unpublish until an admin reviews.',
      },
      {
        'q': 'Where do likes and reviews appear?',
        'a':
            'Your own actions appear under Profile → My Activity. When others interact with your stories you see them under Notifications → Activity.',
      },
    ],
    'Notifications & Privacy': [
      {
        'q': 'What is the Activity tab?',
        'a':
            'Notifications → Activity lists likes, comments, reviews, saves and follows on your work, with story covers when available.',
      },
      {
        'q': 'How do I manage notification settings?',
        'a':
            'More → Settings → Notifications. Toggle reading reminders, new releases, recommendations and system messages.',
      },
      {
        'q': 'Who can see my profile?',
        'a':
            'Public profile shows display name, bio, stories and public lists. Private reading lists stay private to you.',
      },
    ],
    'Support': [
      {
        'q': 'How do I contact support?',
        'a':
            'Use More → Support → Contact Us or Live Chat. Live Chat messages go to the admin team and replies appear in the same chat.',
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Help Center'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search for help...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final e in _faq.entries) ...[
            Builder(
              builder: (context) {
                final items = e.value.where((item) {
                  if (q.isEmpty) return true;
                  return item['q']!.toLowerCase().contains(q) ||
                      item['a']!.toLowerCase().contains(q);
                }).toList();
                if (items.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        bottom: 8,
                        top: 8,
                      ),
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          color: MorePageChrome.purple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      decoration: MorePageChrome.card(context),
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            ListTile(
                              title: Text(items[i]['q']!),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 20,
                              ),
                              onTap: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (_) => Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    20 +
                                        MediaQuery.of(
                                          context,
                                        ).viewInsets.bottom,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        items[i]['q']!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        items[i]['a']!,
                                        style: const TextStyle(
                                          height: 1.45,
                                          color: MorePageChrome.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Got it'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (i < items.length - 1)
                              const Divider(height: 1, indent: 16),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// User ↔ Admin live support chat (backed by /api/chat/messages).
class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key, required this.apiService});
  final ApiService apiService;
  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.apiService.fetchChatMessages();
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _loading = false;
      });
      _jumpBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.apiService.sendChatMessage(text);
      _ctrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Chat'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: MorePageChrome.purple.withValues(alpha: 0.08),
            child: const Text(
              'Messages are delivered to the admin team. Replies appear here.',
              style: TextStyle(fontSize: 12, color: MorePageChrome.muted),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No messages yet.\nSay hello — support will reply here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MorePageChrome.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final sender = (m['sender'] ?? 'user')
                          .toString()
                          .toLowerCase();
                      final isUser = sender == 'user';
                      final body = (m['message'] ?? '').toString();
                      final when = (m['created_at'] ?? '').toString();
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? MorePageChrome.purple
                                : (isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFF3F0FA)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: MorePageChrome.purple,
                                    ),
                                  ),
                                ),
                              Text(
                                body,
                                style: TextStyle(
                                  color: isUser ? Colors.white : null,
                                  height: 1.35,
                                ),
                              ),
                              if (when.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    when,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isUser
                                          ? Colors.white70
                                          : MorePageChrome.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: MorePageChrome.purple,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key, required this.apiService, this.email = '', this.username = ''});

  final ApiService apiService;
  final String email;
  final String username;

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  static const _purple = Color(0xFF6C3CE1);
  static const _paper = Color(0xFFF7F5FC);
  static const _ink = Color(0xFF1A1A2E);

  final _messageCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  String? _topic;
  bool _sending = false;
  bool _historyLoading = true;
  String? _ticketId;
  int _tab = 0; // 0 contact, 1 history
  List<Map<String, dynamic>> _history = const [];

  static const _topics = [
    'General Question',
    'Technical Problem',
    'Account & Login',
    'Story / Chapter Issue',
    'Writing & Publishing',
    'Report a Story',
    'Report a User',
    'Copyright / Content Issue',
    'Payment / Subscription',
    'Feedback & Suggestions',
    'Partnership / Business',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final items = await widget.apiService.fetchMySupportRequests();
      if (!mounted) return;
      setState(() {
        _history = items;
        _historyLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _submit() async {
    final topic = _topic;
    final msg = _messageCtrl.text.trim();
    if (topic == null || topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a topic')),
      );
      return;
    }
    if (topic == 'Other' && _otherCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify your reason')),
      );
      return;
    }
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your message can\'t be empty')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final displayTopic = topic == 'Other' ? 'Other: ${_otherCtrl.text.trim()}' : topic;
      final res = await widget.apiService.submitSupportRequest({
        'email': widget.email,
        'first_name': widget.username.isNotEmpty ? widget.username : 'Reader',
        'issue': displayTopic,
        'subject': displayTopic,
        'description': msg,
        'device_type': 'mobile',
      });
      final id = res is Map ? (res['id'] ?? res['ticket_id'] ?? res['request_id']) : null;
      final ticket = id != null ? '#CNT-$id' : '#CNT-${DateTime.now().millisecondsSinceEpoch % 100000}';
      if (!mounted) return;
      setState(() {
        _ticketId = ticket;
        _messageCtrl.clear();
        _otherCtrl.clear();
        _topic = null;
      });
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent · Ticket $ticket')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'progress':
      case 'in_progress':
      case 'in progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return 'Open';
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF4C7359);
      case 'progress':
      case 'in_progress':
      case 'in progress':
        return const Color(0xFF3B5486);
      case 'closed':
        return Colors.grey;
      default:
        return const Color(0xFF8F6521);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : _paper;
    final card = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fg = isDark ? Colors.white : _ink;
    final muted = isDark ? Colors.white70 : const Color(0xFF5B5F66);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Contact Us'),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: fg,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _tab = 0),
                  child: Text(
                    'Contact Us',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _tab == 0 ? _purple : muted,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() => _tab = 1);
                    _loadHistory();
                  },
                  child: Text(
                    'My Requests',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _tab == 1 ? _purple : muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _purple,
        onRefresh: _loadHistory,
        child: _tab == 0 ? _buildContactForm(card, fg, muted) : _buildHistory(card, fg, muted),
      ),
    );
  }

  Widget _buildContactForm(Color card, Color fg, Color muted) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          'Contact us',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: fg),
        ),
        const SizedBox(height: 6),
        Text(
          'Have a question, suggestion, or problem? Let us know — our team reads every message.',
          style: TextStyle(color: muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E4F5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _readonlyBox('Username', widget.username.isEmpty ? 'Reader' : widget.username, muted, fg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _readonlyBox('Email', widget.email.isEmpty ? '—' : widget.email, muted, fg),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('What can we help you with?', style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _topic,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isLight(card) ? Colors.white : const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                hint: const Text('Select a topic'),
                items: _topics
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _topic = v),
              ),
              if (_topic == 'Other') ...[
                const SizedBox(height: 14),
                Text('Please specify your reason', style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 8),
                TextField(
                  controller: _otherCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tell us what you would like to contact us about...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text('Your message', style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 8),
              TextField(
                controller: _messageCtrl,
                maxLines: 6,
                maxLength: 1000,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tell us how we can help you...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _sending ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send message', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              if (_ticketId != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EDFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _purple.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✓ Your message has been sent', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Thank you. Our team will review it and reply if needed.', style: TextStyle(color: muted, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text('Ticket ID: $_ticketId', style: const TextStyle(fontWeight: FontWeight.w700, color: _purple)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool isLight(Color c) => c.computeLuminance() > 0.5;

  Widget _readonlyBox(String label, String value, Color muted, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECFA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _buildHistory(Color card, Color fg, Color muted) {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }
    if (_history.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.inbox_outlined, size: 48, color: muted),
          const SizedBox(height: 12),
          Center(child: Text('No contact requests yet.', style: TextStyle(color: muted))),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final h = _history[i];
        final status = '${h['status'] ?? 'open'}';
        final reply = '${h['admin_reply'] ?? ''}'.trim();
        return Material(
          color: card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: reply.isEmpty
                ? null
                : () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (ctx) => Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${h['ticket_id'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('Your message', style: TextStyle(color: muted, fontSize: 12)),
                            Text('${h['message'] ?? ''}', style: TextStyle(color: fg)),
                            if (reply.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Text('Support reply', style: TextStyle(fontWeight: FontWeight.w700, color: _purple)),
                              const SizedBox(height: 6),
                              Text(reply, style: TextStyle(color: fg, height: 1.4)),
                            ],
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    );
                  },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E4F5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${h['topic'] ?? 'Request'}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: fg),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${h['ticket_id'] ?? ''}', style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 8),
                  Text(
                    'Sent ${h['created_at'] ?? ''}',
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                  if (reply.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tap to view support reply',
                        style: TextStyle(color: _purple, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key, required this.apiService});
  final ApiService apiService;
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  final Map<String, bool> _flags = {
    'reading_reminders': true,
    'new_releases': true,
    'recommendations': false,
    'marketing': false,
    'system': true,
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.apiService.fetchUserPreferences();
      final n = (p['notifications'] as Map?)?.cast<String, dynamic>() ?? {};
      for (final k in _flags.keys) {
        if (n[k] is bool) _flags[k] = n[k] as bool;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save(String key, bool value) async {
    final previous = _flags[key] ?? false;
    setState(() => _flags[key] = value);
    try {
      await widget.apiService.updateUserPreferences({
        'notifications': Map<String, bool>.from(_flags),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _flags[key] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save notification setting: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'reading_reminders',
        'Reading Reminders',
        'Get reminded to continue your reading',
      ),
      ('new_releases', 'New Releases', 'Be notified about new book releases'),
      ('recommendations', 'Recommendations', 'Receive book recommendations'),
      ('marketing', 'Marketing', 'Receive updates and offers'),
      ('system', 'System Notifications', 'Important system updates and alerts'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  decoration: MorePageChrome.card(context),
                  child: Column(
                    children: [
                      for (final it in items)
                        SwitchListTile.adaptive(
                          value: _flags[it.$1] ?? false,
                          activeColor: MorePageChrome.purple,
                          title: Text(
                            it.$2,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            it.$3,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onChanged: (v) => _save(it.$1, v),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class AppLanguageScreen extends StatefulWidget {
  const AppLanguageScreen({super.key, required this.apiService});
  final ApiService apiService;
  @override
  State<AppLanguageScreen> createState() => _AppLanguageScreenState();
}

class _AppLanguageScreenState extends State<AppLanguageScreen> {
  String _lang = 'en';
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.apiService.fetchUserPreferences();
      _lang = (p['language'] ?? 'en').toString();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pick(String code) async {
    setState(() => _lang = code);
    try {
      await widget.apiService.updateUserPreferences({'language': code});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      ('en', 'English', 'Default'),
      ('si', 'සිංහල (Sinhala)', 'සිංහල'),
      ('ta', 'தமிழ் (Tamil)', 'தமிழ்'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('App Language'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  decoration: MorePageChrome.card(context),
                  child: Column(
                    children: [
                      for (final o in options)
                        RadioListTile<String>(
                          value: o.$1,
                          groupValue: _lang,
                          activeColor: MorePageChrome.purple,
                          title: Text(
                            o.$2,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(o.$3),
                          onChanged: (v) {
                            if (v != null) _pick(v);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class FavouriteGenresScreen extends StatefulWidget {
  const FavouriteGenresScreen({super.key, required this.apiService});
  final ApiService apiService;
  @override
  State<FavouriteGenresScreen> createState() => _FavouriteGenresScreenState();
}

class _FavouriteGenresScreenState extends State<FavouriteGenresScreen> {
  static const _all = [
    'Fantasy',
    'Romance',
    'Mystery',
    'Thriller',
    'Sci-Fi',
    'Horror',
    'Adventure',
    'Historical Fiction',
    'Poetry',
  ];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.apiService.fetchUserPreferences();
      final list = (p['favourite_genres'] as List?) ?? [];
      _selected.addAll(list.map((e) => e.toString()));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.apiService.updateUserPreferences({
        'favourite_genres': _selected.toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Favourite genres saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favourite Genres'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Select your favourite genres',
                          style: TextStyle(color: MorePageChrome.muted),
                        ),
                      ),
                      Container(
                        decoration: MorePageChrome.card(context),
                        child: Column(
                          children: [
                            for (final g in _all)
                              CheckboxListTile(
                                value: _selected.contains(g),
                                activeColor: MorePageChrome.purple,
                                title: Text(g),
                                onChanged: (v) => setState(() {
                                  if (v == true)
                                    _selected.add(g);
                                  else
                                    _selected.remove(g);
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MorePageChrome.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _saving ? 'Saving...' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ContentWarningsScreen extends StatefulWidget {
  const ContentWarningsScreen({super.key, required this.apiService});
  final ApiService apiService;
  @override
  State<ContentWarningsScreen> createState() => _ContentWarningsScreenState();
}

class _ContentWarningsScreenState extends State<ContentWarningsScreen> {
  static const _all = [
    'Violence',
    'Strong Language',
    'Sexual Content',
    'Self-harm',
    'Substance Use',
    'Hate Speech',
  ];
  final Map<String, bool> _flags = {for (final w in _all) w: true};
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.apiService.fetchUserPreferences();
      final m = (p['content_warnings'] as Map?)?.cast<String, dynamic>() ?? {};
      for (final k in _all) {
        if (m[k] is bool) _flags[k] = m[k] as bool;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.apiService.updateUserPreferences({
        'content_warnings': Map<String, bool>.from(_flags),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content warning preferences saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content Warnings'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          "Choose content types you'd like to be warned about",
                          style: TextStyle(color: MorePageChrome.muted),
                        ),
                      ),
                      Container(
                        decoration: MorePageChrome.card(context),
                        child: Column(
                          children: [
                            for (final w in _all)
                              SwitchListTile.adaptive(
                                value: _flags[w] ?? false,
                                activeColor: MorePageChrome.purple,
                                title: Text(w),
                                onChanged: (v) => setState(() => _flags[w] = v),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MorePageChrome.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _saving ? 'Saving...' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class CookiePreferencesScreen extends StatefulWidget {
  const CookiePreferencesScreen({super.key, required this.apiService});
  final ApiService apiService;
  @override
  State<CookiePreferencesScreen> createState() =>
      _CookiePreferencesScreenState();
}

class _CookiePreferencesScreenState extends State<CookiePreferencesScreen> {
  final Map<String, bool> _flags = {
    'essential': true,
    'analytics': true,
    'marketing': false,
    'functional': true,
  };
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.apiService.fetchUserPreferences();
      final m = (p['cookies'] as Map?)?.cast<String, dynamic>() ?? {};
      for (final k in _flags.keys) {
        if (m[k] is bool) _flags[k] = m[k] as bool;
      }
      _flags['essential'] = true;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      await widget.apiService.updateUserPreferences({
        'cookies': Map<String, bool>.from(_flags)..['essential'] = true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cookie preferences saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'essential',
        'Essential Cookies',
        'Required for the app to function properly',
        false,
      ),
      (
        'analytics',
        'Analytics Cookies',
        'Help us understand how you use our app',
        true,
      ),
      (
        'marketing',
        'Marketing Cookies',
        'Used to deliver relevant ads and offers',
        true,
      ),
      (
        'functional',
        'Functional Cookies',
        'Remember your preferences and settings',
        true,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Cookie Preferences'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Choose which cookies you want to allow. You can change these settings at any time.',
                          style: TextStyle(color: MorePageChrome.muted),
                        ),
                      ),
                      Container(
                        decoration: MorePageChrome.card(context),
                        child: Column(
                          children: [
                            for (final it in items)
                              SwitchListTile.adaptive(
                                value: _flags[it.$1] ?? false,
                                activeColor: MorePageChrome.purple,
                                title: Text(
                                  it.$2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  it.$3,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onChanged: it.$4
                                    ? (v) => setState(() => _flags[it.$1] = v)
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MorePageChrome.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Save Preferences',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class LegalTextScreen extends StatelessWidget {
  const LegalTextScreen({
    super.key,
    required this.title,
    required this.sections,
  });
  final String title;
  final List<(String, String)> sections;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Last updated: 1 May 2024',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          for (final s in sections) ...[
            Text(
              s.$1,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(s.$2, style: const TextStyle(height: 1.5, fontSize: 14)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

List<(String, String)> termsSections() => const [
  (
    '1. Acceptance of Terms',
    'By using our app, you agree to these Terms of Service. If you do not agree, please do not use our app.',
  ),
  (
    '2. Use of Service',
    'You must be at least 13 years old to use this app. You agree to use the app only for lawful purposes.',
  ),
  (
    '3. User Content',
    'You retain ownership of content you post, but you grant us a license to use it for providing our services.',
  ),
  (
    '4. Termination',
    'We may terminate or suspend your account if you violate these terms.',
  ),
];

List<(String, String)> privacySections() => const [
  (
    '1. Information We Collect',
    'We collect information you provide to us, such as your name, email, and usage data.',
  ),
  (
    '2. How We Use Information',
    'We use your information to provide and improve our services, and communicate with you.',
  ),
  (
    '3. Information Sharing',
    'We do not sell your personal information. We may share data with trusted partners.',
  ),
  (
    '4. Your Rights',
    'You can access, update, or delete your information at any time.',
  ),
];

Future<bool> showSignOutConfirmDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade400, width: 2),
            ),
            child: const Icon(Icons.logout, size: 28),
          ),
          const SizedBox(height: 18),
          const Text(
            'Are you sure you want to sign out?',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            'You will need to sign in again to access your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}
