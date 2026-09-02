import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'story_detail_screen.dart';

/// Galatea-style profile: cover + overlapping avatar, stats, About/Stories/Wall/Activity/Reviews.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.apiService,
    required this.achievements,
    this.viewingUserId,
  });

  final ProfileModel profile;
  final ApiService apiService;
  final List<AchievementGroupModel> achievements;
  final int? viewingUserId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController;

  Map<String, dynamic>? _userProfile;
  bool _loadingProfile = true;
  bool _isFollowing = false;
  bool _isOwnProfile = true;

  List<Map<String, dynamic>> _stories = const [];
  List<Map<String, dynamic>> _wall = const [];
  List<Map<String, dynamic>> _activity = const [];
  List<Map<String, dynamic>> _reviews = const [];
  List<Map<String, dynamic>> _readingLists = const [];
  String _storyQuery = '';
  String _storySort = 'Recently Updated';
  String _storyFilter = 'All stories';

  static const Color brand = Color(0xFF6C3CE1);
  static const Color muted = Color(0xFF8A8F98);
  static const Color cardBg = Color(0xFFF7F8FA);
  static const Color border = Color(0xFFE8EAED);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loadingProfile = true);
    try {
      Map<String, dynamic> me = {};
      try {
        me = await widget.apiService.fetchMeStrict();
      } catch (_) {
        try {
          await Future<void>.delayed(const Duration(seconds: 2));
          me = await widget.apiService.fetchMe();
        } catch (_) {
          me = {};
        }
      }
      final meId = _asInt(me['id'] ?? me['user_id']);
      final viewId = widget.viewingUserId;
      _isOwnProfile = viewId == null || (meId != 0 && viewId == meId);

      final int targetId = _isOwnProfile
          ? (meId != 0 ? meId : (widget.profile.id ?? 0))
          : (viewId ?? 0);

      if (_isOwnProfile) {
        if (me.isNotEmpty) {
          _userProfile = {
            ...me,
            'display_name':
                (me['display_name'] ?? me['name'] ?? widget.profile.displayName)
                    .toString(),
            'photo_url':
                (me['photo_url'] ?? me['avatar_url'] ?? widget.profile.photoUrl)
                    .toString(),
            'cover_url': (me['cover_url'] ?? widget.profile.coverUrl)
                .toString(),
            'bio': (me['bio'] ?? '').toString(),
            'gender': (me['gender'] ?? '').toString(),
            'birth_date': (me['birth_date'] ?? '').toString(),
            'username': (me['username'] ?? widget.profile.username).toString(),
          };
        } else {
          _userProfile = {
            'id': widget.profile.id,
            'display_name': widget.profile.displayName,
            'username': widget.profile.username,
            'following': widget.profile.following,
            'followers': widget.profile.followers,
            'chapters_read': widget.profile.chaptersRead,
            'social_karma': widget.profile.socialKarma,
            'day_streak': widget.profile.dayStreak,
            'photo_url': widget.profile.photoUrl,
            'cover_url': widget.profile.coverUrl,
          };
        }
      } else {
        _userProfile = await widget.apiService.fetchProfile(viewId!);
        try {
          _isFollowing = await widget.apiService.fetchAuthorFollowing(viewId);
        } catch (_) {
          _isFollowing = false;
        }
      }

      // Always load from backend — never use bootstrap fake lists/stories
      List stories = const [];
      List wall = const [];
      List activity = const [];
      List reviews = const [];
      List lists = const [];

      if (targetId > 0) {
        final results = await Future.wait([
          (_isOwnProfile
                  ? widget.apiService.fetchWriterStories()
                  : widget.apiService.fetchUserStories(targetId))
              .catchError((_) => <Map<String, dynamic>>[]),
          widget.apiService
              .fetchUserWall(targetId)
              .catchError((_) => <Map<String, dynamic>>[]),
          (_isOwnProfile
                  ? widget.apiService.fetchMyActivity()
                  : widget.apiService.fetchUserActivity(targetId))
              .catchError((_) => <Map<String, dynamic>>[]),
          (_isOwnProfile
                  ? widget.apiService.fetchMyReviews()
                  : widget.apiService.fetchUserReviews(targetId))
              .catchError((_) => <Map<String, dynamic>>[]),
          (_isOwnProfile
                  ? widget.apiService.fetchReadingLists()
                  : widget.apiService.fetchUserReadingLists(targetId))
              .catchError((_) => <Map<String, dynamic>>[]),
        ]);
        stories = List<Map<String, dynamic>>.from(results[0] as List);
        wall = List<Map<String, dynamic>>.from(results[1] as List);
        activity = List<Map<String, dynamic>>.from(results[2] as List);
        reviews = List<Map<String, dynamic>>.from(results[3] as List);
        lists = List<Map<String, dynamic>>.from(results[4] as List);
        // Own profile: if activity empty, merge live notifications (likes/comments/follows)
        if (_isOwnProfile && activity.isEmpty) {
          try {
            final notes = await widget.apiService.fetchNotifications();
            activity = notes
                .map((n) => {
                      'type': n['type'] ?? 'system',
                      'title': n['title'] ?? n['message'] ?? '',
                      'message': n['message'] ?? '',
                      'actor_name': n['actor_name'] ?? '',
                      'actor_photo': n['actor_photo'] ?? '',
                      'cover_path': n['cover_path'] ?? '',
                      'book_id': n['book_id'],
                      'created_at': n['created_at'] ?? '',
                    })
                .toList();
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _stories = stories.cast<Map<String, dynamic>>();
        _wall = wall.cast<Map<String, dynamic>>();
        _activity = activity.cast<Map<String, dynamic>>();
        _reviews = reviews.cast<Map<String, dynamic>>();
        _readingLists = lists.cast<Map<String, dynamic>>();
        _loadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  String _s(dynamic v) => v == null ? '' : '$v'.trim();
  int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  bool get _isAuthor => widget.profile.isAuthor;

  String get _displayName {
    final n = _s(_userProfile?['display_name']);
    if (n.isNotEmpty) return n;
    if (widget.profile.displayName.trim().isNotEmpty) {
      return widget.profile.displayName;
    }
    return widget.profile.username;
  }

  String get _username {
    final u = _s(_userProfile?['username']);
    if (u.isNotEmpty) return u.replaceAll('@', '');
    return widget.profile.username.replaceAll('@', '');
  }

  String get _bio {
    final b = _s(_userProfile?['bio']);
    if (b.isNotEmpty) return b;
    return 'Just a reader turning pages into worlds.';
  }

  String get _aboutLong {
    final a = _s(_userProfile?['about'] ?? _userProfile?['bio']);
    return a.isNotEmpty ? a : _bio;
  }

  String get _facebookUrl {
    return _s(
      _userProfile?['facebook_url'] ??
          _userProfile?['facebook'] ??
          _userProfile?['fb_url'],
    );
  }

  int get _following =>
      _asInt(_userProfile?['following'] ?? widget.profile.following);
  int get _followers =>
      _asInt(_userProfile?['followers'] ?? widget.profile.followers);
  int get _chaptersRead =>
      _asInt(_userProfile?['chapters_read'] ?? widget.profile.chaptersRead);
  int get _karma =>
      _asInt(_userProfile?['social_karma'] ?? widget.profile.socialKarma);
  int get _streak =>
      _asInt(_userProfile?['day_streak'] ?? widget.profile.dayStreak);

  String get _avatarUrl {
    final p = _s(
      _userProfile?['avatar_url'] ??
          _userProfile?['photo_url'] ??
          _userProfile?['photoUrl'] ??
          _userProfile?['avatar'] ??
          widget.profile.photoUrl,
    );
    if (p.isEmpty) return '';
    return widget.apiService.resolveAssetUrl(p);
  }

  String get _coverUrl {
    final p = _s(
      _userProfile?['cover_url'] ??
          _userProfile?['banner_url'] ??
          _userProfile?['coverUrl'] ??
          widget.profile.coverUrl,
    );
    if (p.isEmpty) return '';
    return widget.apiService.resolveAssetUrl(p);
  }

  Future<void> _toggleFollow() async {
    final id = widget.viewingUserId ?? widget.profile.id;
    if (id == null || _isOwnProfile) return;
    final wasFollowing = _isFollowing;
    try {
      final dynamic res = wasFollowing
          ? await widget.apiService.unfollowAuthor(id)
          : await widget.apiService.followAuthor(id);
      if (!mounted) return;
      int? followers;
      if (res is Map) {
        followers = (res['followers'] as num?)?.toInt();
      }
      setState(() {
        _isFollowing = !wasFollowing;
        if (_userProfile != null) {
          if (followers != null) {
            _userProfile = {..._userProfile!, 'followers': followers};
          } else {
            final cur = _asInt(_userProfile!['followers']);
            _userProfile = {
              ..._userProfile!,
              'followers': _isFollowing ? cur + 1 : (cur > 0 ? cur - 1 : 0),
            };
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final text = (msg.contains('timeout') || msg.contains('timed out'))
          ? 'Server busy — tap Follow again'
          : (msg.contains('401') || msg.contains('unauthorized'))
          ? 'Sign in to follow authors'
          : 'Could not update follow';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Share profile',
                style: TextStyle(color: Color(0xFF2B6CB0)),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text(
                'Block user',
                style: TextStyle(color: Color(0xFF2B6CB0)),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text(
                'Report user',
                style: TextStyle(color: Color(0xFF2B6CB0)),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text('Cancel', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    if (!_isOwnProfile) return;
    final nameCtrl = TextEditingController(text: _displayName);
    final bioCtrl = TextEditingController(text: _bio);
    final facebookCtrl = TextEditingController(text: _facebookUrl);
    String photoUrl = _s(
      _userProfile?['photo_url'] ?? _userProfile?['avatar_url'],
    );
    String coverUrl = _s(_userProfile?['cover_url']);
    bool uploading = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Edit profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                    ),
                    TextField(
                      controller: bioCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Bio'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading
                                ? null
                                : () async {
                                    final picked = await _imagePicker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (picked == null) return;
                                    setModal(() => uploading = true);
                                    try {
                                      final bytes = await picked.readAsBytes();
                                      final res = await widget.apiService
                                          .uploadUserImage(bytes, picked.name);
                                      final path =
                                          (res['path'] ??
                                                  res['photo_url'] ??
                                                  res['url'] ??
                                                  '')
                                              .toString();
                                      if (path.isNotEmpty) {
                                        setModal(() => photoUrl = path);
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Profile photo updated — tap Save',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text('Upload failed: $e'),
                                          ),
                                        );
                                      }
                                    } finally {
                                      setModal(() => uploading = false);
                                    }
                                  },
                            icon: const Icon(Icons.person),
                            label: Text(
                              uploading ? 'Uploading…' : 'Profile photo',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading
                                ? null
                                : () async {
                                    final picked = await _imagePicker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (picked == null) return;
                                    setModal(() => uploading = true);
                                    try {
                                      final bytes = await picked.readAsBytes();
                                      final res = await widget.apiService
                                          .uploadUserImage(bytes, picked.name);
                                      final path =
                                          (res['path'] ??
                                                  res['cover_url'] ??
                                                  res['photo_url'] ??
                                                  res['url'] ??
                                                  '')
                                              .toString();
                                      if (path.isNotEmpty) {
                                        setModal(() => coverUrl = path);
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Cover updated — tap Save',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text('Upload failed: $e'),
                                          ),
                                        );
                                      }
                                    } finally {
                                      setModal(() => uploading = false);
                                    }
                                  },
                            icon: const Icon(Icons.image),
                            label: const Text('Cover'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: uploading
                            ? null
                            : () async {
                                try {
                                  await widget.apiService.updateMe({
                                    'display_name': nameCtrl.text.trim(),
                                    'bio': bioCtrl.text.trim(),
                                    'facebook_url': facebookCtrl.text.trim(),
                                    if (photoUrl.isNotEmpty)
                                      'photo_url': photoUrl,
                                    if (coverUrl.isNotEmpty)
                                      'cover_url': coverUrl,
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _loadAll();
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                }
                              },
                        child: uploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredStories {
    var list = List<Map<String, dynamic>>.from(_stories);
    final q = _storyQuery.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((s) {
        final title = _s(s['title']).toLowerCase();
        final desc = _s(s['description']).toLowerCase();
        return title.contains(q) || desc.contains(q);
      }).toList();
    }
    bool isCompleted(Map<String, dynamic> s) {
      final st = _s(s['status_text']).toLowerCase();
      // Only story-level Completed/Published — not chapter "submitted"
      return st.contains('complete') || st.contains('publish');
    }

    if (_storyFilter == 'Completed') {
      list = list.where(isCompleted).toList();
    } else if (_storyFilter == 'In progress') {
      list = list.where((s) => !isCompleted(s)).toList();
    }
    if (_storySort == 'Name') {
      list.sort(
        (a, b) => _s(
          a['title'],
        ).toLowerCase().compareTo(_s(b['title']).toLowerCase()),
      );
    } else if (_storySort == 'Last Read') {
      list.sort(
        (a, b) => _s(
          b['updated_at'] ?? b['created_at'],
        ).compareTo(_s(a['updated_at'] ?? a['created_at'])),
      );
    }
    // Recently Updated: keep API order (already newest-first when possible)
    return list;
  }

  void _showStorySortSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Sort by',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Sort by',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final opt in ['Recently Updated', 'Name', 'Last Read'])
                RadioListTile<String>(
                  dense: true,
                  activeColor: brand,
                  title: Text(opt),
                  value: opt,
                  groupValue: _storySort,
                  onChanged: (v) {
                    setState(() => _storySort = v!);
                    Navigator.pop(ctx);
                  },
                ),
              const Text(
                'Filter',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final opt in ['All stories', 'Completed', 'In progress'])
                RadioListTile<String>(
                  dense: true,
                  activeColor: brand,
                  title: Text(opt),
                  value: opt,
                  groupValue: _storyFilter,
                  onChanged: (v) {
                    setState(() => _storyFilter = v!);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator(color: brand))
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Facebook-style: taller cover + avatar drawn ON TOP of cover (higher z-index)
                  // and still visible below the cover edge.
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: const Color(0xFF3B2A6B),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: _showMoreMenu,
                      ),
                    ],
                    // Stack directly (not FlexibleSpaceBar) so clipBehavior: Clip.none
                    // keeps the avatar painted above the cover and slightly below the bar.
                    flexibleSpace: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        if (_coverUrl.isNotEmpty)
                          Image.network(
                            _coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _defaultCover(),
                          )
                        else
                          _defaultCover(),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.15),
                                Colors.black.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                        // Avatar sits on the bottom edge of the cover (above cover in z-order)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: -44,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: const Color(0xFFE2E8F0),
                                backgroundImage: _avatarUrl.isNotEmpty
                                    ? NetworkImage(_avatarUrl)
                                    : null,
                                child: _avatarUrl.isEmpty
                                    ? Text(
                                        _displayName.isNotEmpty
                                            ? _displayName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w700,
                                          color: muted,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Space so content starts below the overlapping avatar
                  SliverToBoxAdapter(child: _buildIdentityBlock()),
                  // Sticky tabs
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.center,
                        labelColor: brand,
                        unselectedLabelColor: muted,
                        indicatorColor: brand,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        tabs: const [
                          Tab(text: 'About'),
                          Tab(text: 'Stories'),
                          Tab(text: 'Wall'),

                          Tab(text: 'Reviews'),
                          Tab(text: 'My Activity'),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(),
                  _buildStoriesTab(),
                  _buildWallTab(),
                  _buildReviewsTab(),
                  _buildMyActivityTab(),
                ],
              ),
            ),
    );
  }

  Widget _defaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B2A6B), Color(0xFF6C3CE1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, size: 64, color: Colors.white24),
      ),
    );
  }

  /// Avatar overlaps cover; name / bio / stats / Follow sit on white below.
  Widget _buildIdentityBlock() {
    // Avatar is drawn inside SliverAppBar (higher z-index than cover).
    // Only leave top padding so name/bio sit below the overlapping avatar.
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          // Name + verified
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              // Pen badge for authors (no green check)
              if (_isAuthor) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C3CE1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 11, color: Colors.white),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '@$_username',
            style: const TextStyle(fontSize: 14, color: muted),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              _bio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Color(0xFF4A4A4A),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Following | Followers
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _countCol('$_following', 'Following'),
              Container(
                width: 1,
                height: 28,
                color: border,
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              _countCol('$_followers', 'Followers'),
            ],
          ),
          const SizedBox(height: 14),
          // Reading stats strip (UI)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _ProfileStatChip(
                    icon: Icons.menu_book_outlined,
                    value: '$_chaptersRead',
                    label: 'Chapters',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProfileStatChip(
                    icon: Icons.local_fire_department_outlined,
                    value: '$_streak',
                    label: 'Day streak',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProfileStatChip(
                    icon: Icons.auto_awesome_outlined,
                    value: '$_karma',
                    label: 'Karma',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Follow / Edit button — solid green Follow (video), outlined otherwise
          if (_isOwnProfile)
            OutlinedButton(
              onPressed: _editProfile,
              style: OutlinedButton.styleFrom(
                foregroundColor: brand,
                side: const BorderSide(color: Color(0xFF6C3CE1), width: 1.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Edit profile',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else if (_isFollowing)
            OutlinedButton(
              onPressed: _toggleFollow,
              style: OutlinedButton.styleFrom(
                foregroundColor: brand,
                side: const BorderSide(color: Color(0xFF6C3CE1), width: 1.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Following',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Follow',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _countCol(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: muted)),
      ],
    );
  }

  // ─── About ───────────────────────────────────────────────
  Widget _buildAboutTab() {
    final gender = _s(_userProfile?['gender']);
    final birth = _s(_userProfile?['birth_date']);
    // shown in details below

    final lists = _readingLists;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (gender.isNotEmpty || birth.isNotEmpty) ...[
          if (gender.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline, size: 20),
              title: Text(gender),
              dense: true,
            ),
          if (birth.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined, size: 20),
              title: Text(birth),
              dense: true,
            ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        Text(
          'About $_displayName',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _aboutLong,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF3A3A3A),
          ),
        ),
        if (_facebookUrl.isNotEmpty) ...[
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              // open externally via share_plus or url - use simple snack for now
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD6E4FF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _facebookUrl,
                      style: const TextStyle(
                        color: Color(0xFF1877F2),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 16, color: Color(0xFF1877F2)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Reading Lists',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Public Reading Lists',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 12),
        if (lists.isEmpty)
          const Text(
            'No public reading lists yet.',
            style: TextStyle(color: muted),
          )
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: lists.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final list = lists[i];
                final name = _s(list['name'] ?? list['title']);
                final count = _asInt(list['story_count'] ?? list['count']);
                // Multi-cover collage (Inkitt-style stacked book covers)
                final List<String> coverList = [];
                final dynamic rawCovers = list['covers'];
                if (rawCovers is List) {
                  for (final c in rawCovers) {
                    final s = _s(c);
                    if (s.isNotEmpty) coverList.add(s);
                  }
                }
                if (coverList.isEmpty) {
                  final single = _s(list['cover_path'] ?? list['cover_url']);
                  if (single.isNotEmpty) coverList.add(single);
                }
                final listId = _asInt(list['id']);
                return GestureDetector(
                  onTap: listId > 0
                      ? () async {
                          try {
                            final detail = await widget.apiService
                                .fetchReadingListDetail(listId);
                            if (!context.mounted) return;
                            final items = detail['items'];
                            final itemList = items is List
                                ? List<Map<String, dynamic>>.from(items)
                                : <Map<String, dynamic>>[];
                            await showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              builder: (ctx) {
                                return DraggableScrollableSheet(
                                  expand: false,
                                  initialChildSize: 0.7,
                                  maxChildSize: 0.95,
                                  minChildSize: 0.4,
                                  builder: (_, scrollCtrl) {
                                    return Column(
                                      children: [
                                        const SizedBox(height: 8),
                                        Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name.isEmpty
                                                      ? 'Reading List'
                                                      : name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '$count Stories',
                                                style: const TextStyle(
                                                  color: muted,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        Expanded(
                                          child: itemList.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    'No stories in this list yet.',
                                                  ),
                                                )
                                              : ListView.builder(
                                                  controller: scrollCtrl,
                                                  itemCount: itemList.length,
                                                  itemBuilder: (_, i) {
                                                    final it = itemList[i];
                                                    final book =
                                                        it['book'] is Map
                                                        ? Map<
                                                            String,
                                                            dynamic
                                                          >.from(
                                                            it['book'] as Map,
                                                          )
                                                        : it;
                                                    final title = _s(
                                                      book['title'],
                                                    );
                                                    final author = _s(
                                                      book['author'],
                                                    );
                                                    final cPath = _s(
                                                      book['cover_path'] ??
                                                          book['cover_url'],
                                                    );
                                                    final bookId = _asInt(
                                                      book['id'] ??
                                                          it['book_id'],
                                                    );
                                                    return ListTile(
                                                      leading: cPath.isNotEmpty
                                                          ? ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                              child: Image.network(
                                                                widget
                                                                    .apiService
                                                                    .resolveAssetUrl(
                                                                      cPath,
                                                                    ),
                                                                width: 40,
                                                                height: 56,
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorBuilder:
                                                                    (
                                                                      _,
                                                                      _,
                                                                      _,
                                                                    ) => const Icon(
                                                                      Icons
                                                                          .menu_book,
                                                                    ),
                                                              ),
                                                            )
                                                          : const Icon(
                                                              Icons.menu_book,
                                                            ),
                                                      title: Text(
                                                        title.isEmpty
                                                            ? 'Story'
                                                            : title,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      subtitle: Text(
                                                        author,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      onTap: bookId > 0
                                                          ? () {
                                                              Navigator.pop(
                                                                ctx,
                                                              );
                                                              Navigator.of(
                                                                context,
                                                              ).push(
                                                                MaterialPageRoute<
                                                                  void
                                                                >(
                                                                  builder: (_) => StoryDetailScreen(
                                                                    apiService:
                                                                        widget
                                                                            .apiService,
                                                                    book: BookDetailModel(
                                                                      id: bookId,
                                                                      title:
                                                                          title,
                                                                      author:
                                                                          author,
                                                                      description: _s(
                                                                        book['description'],
                                                                      ),
                                                                      statusText: _s(
                                                                        book['status_text'],
                                                                      ),
                                                                      rating:
                                                                          (book['rating']
                                                                                  as num?)
                                                                              ?.toDouble() ??
                                                                          0,
                                                                      genre: _s(
                                                                        book['genre'] ??
                                                                            book['primary_genre'],
                                                                      ),
                                                                      cta:
                                                                          'Read',
                                                                      coverPath:
                                                                          cPath,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          : null,
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not open list: $e'),
                              ),
                            );
                          }
                        }
                      : null,
                  child: SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: coverList.isEmpty
                                ? Container(
                                    color: cardBg,
                                    child: const Icon(
                                      Icons.collections_bookmark_outlined,
                                      color: muted,
                                    ),
                                  )
                                : _ReadingListCollage(
                                    covers: coverList
                                        .map(
                                          (c) => widget.apiService
                                              .resolveAssetUrl(c),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name.isEmpty ? 'List' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '$count Stories',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 28),
        const Text(
          'Achievements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        _buildAchievementsGrid(),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: muted,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsGrid() {
    final groups = widget.achievements;
    if (groups.isEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F3),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    final items = <Widget>[];
    for (final g in groups) {
      for (final a in g.items) {
        items.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  a.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
        );
      }
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: items.take(8).toList(),
    );
  }

  // ─── Stories ─────────────────────────────────────────────
  Widget _buildStoriesTab() {
    final list = _filteredStories;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _storyQuery = v),
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search, color: muted),
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              _filterChip(_storyFilter, onTap: _showStorySortSheet),
              const SizedBox(width: 8),
              _filterChip(_storySort, onTap: _showStorySortSheet),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('No stories yet', style: TextStyle(color: muted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 24),
                  itemBuilder: (context, i) => _storyRow(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.contains('All') ||
                label.contains('Completed') ||
                label.contains('progress'))
              const Icon(Icons.filter_list, size: 14, color: muted)
            else
              const SizedBox.shrink(),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const Icon(Icons.chevron_right, size: 16, color: muted),
          ],
        ),
      ),
    );
  }

  Widget _storyRow(Map<String, dynamic> s) {
    final title = _s(s['title']);
    final desc = _s(s['description']);
    final genre = _s(s['genre'] ?? s['primary_genre']);
    final rating = s['rating'];
    final status = _s(s['status_text']);
    final chapters = _asInt(s['chapter_count'] ?? s['chapters']);
    final cover = _s(s['cover_path'] ?? s['cover_url']);
    final completed =
        status.toLowerCase().contains('complete') ||
        status.toLowerCase().contains('publish');

    return InkWell(
      onTap: () {
        final id = _asInt(s['id']);
        if (id <= 0) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoryDetailScreen(
              apiService: widget.apiService,
              book: BookDetailModel(
                id: id,
                title: title,
                author: _s(s['author']),
                description: desc,
                statusText: status,
                rating: (rating is num)
                    ? rating.toDouble()
                    : double.tryParse('$rating') ?? 0,
                genre: genre,
                cta: _s(s['cta_label']).isEmpty
                    ? 'Read now'
                    : _s(s['cta_label']),
                coverPath: cover,
                authorUserId: _asInt(s['author_user_id'] ?? s['user_id']),
              ),
            ),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: cover.isNotEmpty
                ? Image.network(
                    widget.apiService.resolveAssetUrl(cover),
                    width: 72,
                    height: 100,
                    fit: BoxFit.cover,
                    cacheWidth: 144,
                    cacheHeight: 200,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(width: 72, height: 100, color: cardBg),
                  )
                : Container(width: 72, height: 100, color: cardBg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.bookmark_border,
                        size: 20,
                        color: muted,
                      ),
                      onPressed: () {
                        final id = _asInt(s['id']);
                        _saveBookToReadingList(id);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc.isEmpty ? 'No description' : desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: muted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (rating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Color(0xFFF5A623),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$rating',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (genre.isNotEmpty) _tagChip(genre),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      completed ? Icons.check_circle : Icons.timelapse,
                      size: 14,
                      color: completed ? brand : muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      completed
                          ? 'Completed${chapters > 0 ? ' · $chapters Chapters' : ''}'
                          : (status.toLowerCase().contains('draft') ||
                                    status.isEmpty
                                ? 'Draft${chapters > 0 ? ' · $chapters Chapters' : ''}'
                                : 'Ongoing${chapters > 0 ? ' · $chapters Chapters' : ''}'),
                      style: TextStyle(
                        fontSize: 11,
                        color: completed ? brand : muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF4A4A4A)),
      ),
    );
  }

  Future<void> _composeWallPost() async {
    int resolvedId = widget.viewingUserId ?? 0;
    if (resolvedId == 0) {
      resolvedId = _asInt(_userProfile?['id']);
    }
    if (resolvedId == 0) {
      resolvedId = widget.profile.id ?? 0;
    }
    // Last resort: ask /api/me for current user id
    if (resolvedId == 0) {
      try {
        final me = await widget.apiService.fetchMe();
        resolvedId = _asInt(me['id']);
        if (resolvedId > 0 && mounted) {
          setState(() {
            _userProfile = {...?_userProfile, ...me};
            _isOwnProfile = true;
          });
        }
      } catch (_) {}
    }
    if (resolvedId == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to post on the wall')),
      );
      return;
    }

    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _WallComposeSheet(
          username: _username,
          apiService: widget.apiService,
        );
      },
    );

    if (!mounted) return;
    final body = (text ?? '').trim();
    if (body.isEmpty) return;

    try {
      await widget.apiService.postUserWall(resolvedId, body);
      if (!mounted) return;
      final wall = await widget.apiService.fetchUserWall(resolvedId);
      if (!mounted) return;
      setState(() {
        _wall = wall;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Posted to wall')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not post: $e')));
    }
  }

  // ─── Wall ────────────────────────────────────────────────
  Widget _buildWallTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Composer — posts to backend wall
        InkWell(
          onTap: _composeWallPost,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cardBg,
                backgroundImage: _avatarUrl.isNotEmpty
                    ? NetworkImage(_avatarUrl)
                    : null,
                child: _avatarUrl.isEmpty
                    ? Text(
                        _displayName.isNotEmpty ? _displayName[0] : '?',
                        style: const TextStyle(color: muted),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Write something to $_username',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.image_outlined, color: muted),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_wall.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text('No wall posts yet', style: TextStyle(color: muted)),
            ),
          )
        else
          ..._wall.map((m) {
            final name = _s(
              m['sender_name'] ?? m['username'] ?? m['display_name'] ?? 'User',
            );
            final body = _s(m['message'] ?? m['body'] ?? m['text']);
            final when = _s(m['created_at'] ?? m['time'] ?? '');
            final img = _s(
              m['image_url'] ?? m['image_path'] ?? m['attachment_path'] ?? '',
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final senderPhoto = _s(
                            m['photo_url'] ??
                                m['avatar_url'] ??
                                m['sender_photo'] ??
                                '',
                          );
                          final photoResolved = senderPhoto.isNotEmpty
                              ? widget.apiService.resolveAssetUrl(senderPhoto)
                              : '';
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: cardBg,
                            backgroundImage: photoResolved.isNotEmpty
                                ? NetworkImage(photoResolved)
                                : null,
                            child: photoResolved.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (when.isNotEmpty)
                              Text(
                                when,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.more_horiz, color: muted, size: 18),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _WallPostText(body: body, apiService: widget.apiService),
                  ],
                  if (img.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        widget.apiService.resolveAssetUrl(img),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        onTap: () async {
                          final postId = (m['id'] as num?)?.toInt();
                          if (postId == null) return;
                          try {
                            final res = await widget.apiService.likeWallPost(
                              postId,
                            );
                            if (!mounted) return;
                            final likes = (res['likes'] as num?)?.toInt() ?? 0;
                            final liked = res['liked'] == true;
                            setState(() {
                              m['likes'] = likes;
                              m['liked'] = liked;
                            });
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                        child: Row(
                          children: [
                            Icon(
                              m['liked'] == true
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: m['liked'] == true
                                  ? Colors.redAccent
                                  : muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${m['likes'] ?? 0}',
                              style: TextStyle(
                                fontSize: 12,
                                color: m['liked'] == true
                                    ? Colors.redAccent
                                    : muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () async {
                          final postId = (m['id'] as num?)?.toInt();
                          if (postId == null) return;
                          final ctrl = TextEditingController();
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Comment'),
                              content: TextField(
                                controller: ctrl,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Write a comment…',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Post'),
                                ),
                              ],
                            ),
                          );
                          final text = (ctrl.text).trim();
                          Future.delayed(
                            const Duration(milliseconds: 300),
                            ctrl.dispose,
                          );
                          if (ok != true || text.isEmpty || !mounted) return;
                          try {
                            await widget.apiService.commentWallPost(
                              postId,
                              text,
                            );
                            if (!mounted) return;
                            await _loadAll();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Comment posted')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _saveBookToReadingList(int bookId) async {
    if (bookId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Story not available')));
      return;
    }
    try {
      final lists = await widget.apiService.fetchReadingLists();
      if (!mounted) return;
      if (lists.isEmpty) {
        // Create a default list then add
        final created = await widget.apiService.createReadingList({
          'name': 'My List',
        });
        final listId = (created['id'] as num?)?.toInt() ?? 0;
        if (listId > 0) {
          await widget.apiService.addReadingListItem(listId, bookId);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to My List')));
        return;
      }
      final chosen = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text('Save to reading list')),
                ...lists.map((l) {
                  return ListTile(
                    leading: const Icon(Icons.collections_bookmark_outlined),
                    title: Text('${l['name'] ?? 'List'}'),
                    subtitle: Text(
                      '${l['story_count'] ?? l['storyCount'] ?? 0} stories',
                    ),
                    onTap: () => Navigator.pop(ctx, l),
                  );
                }),
              ],
            ),
          );
        },
      );
      if (chosen == null || !mounted) return;
      final listId = (chosen['id'] as num?)?.toInt() ?? 0;
      if (listId <= 0) return;
      await widget.apiService.addReadingListItem(listId, bookId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${chosen['name'] ?? 'list'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ─── Activity (Facebook-style: likes, comments, follows, reviews, wall) ───
  IconData _activityIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble;
      case 'follow':
        return Icons.person_add;
      case 'review':
        return Icons.star;
      case 'wall':
        return Icons.edit_note;
      case 'story_update':
        return Icons.menu_book;
      default:
        return Icons.notifications;
    }
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'like':
        return const Color(0xFFE74C3C);
      case 'comment':
        return const Color(0xFF3498DB);
      case 'follow':
        return brand;
      case 'review':
        return const Color(0xFFF5A623);
      case 'wall':
        return const Color(0xFF9B59B6);
      default:
        return muted;
    }
  }

  Widget _buildActivityTab() {
    if (_activity.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No recent activity yet.\nLikes, comments, follows and wall posts will show here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.4),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _activity.length,
      itemBuilder: (context, i) {
        final n = _activity[i];
        final type = _s(n['type']);
        final title = _s(n['title']);
        final msg = _s(n['message']);
        final when = _s(n['created_at'] ?? '');
        final cover = _s(n['cover_path']);
        final bookId = _asInt(n['book_id']);
        final actorName = _s(n['actor_name']);
        final actorPhotoRaw = _s(
          n['actor_photo'] ?? n['actor_photo_url'] ?? '',
        );
        final actorPhoto = actorPhotoRaw.isNotEmpty
            ? widget.apiService.resolveAssetUrl(actorPhotoRaw)
            : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: cardBg,
                    backgroundImage: actorPhoto.isNotEmpty
                        ? NetworkImage(actorPhoto)
                        : null,
                    child: actorPhoto.isEmpty
                        ? Text(
                            (actorName.isNotEmpty
                                    ? actorName[0]
                                    : (title.isNotEmpty ? title[0] : '?'))
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        _activityIcon(type),
                        size: 12,
                        color: _activityColor(type),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty
                          ? (actorName.isEmpty ? 'Activity' : actorName)
                          : title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    if (msg.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        msg,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                    ],
                    if (when.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        when,
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                    if (cover.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: bookId > 0
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StoryDetailScreen(
                                      apiService: widget.apiService,
                                      book: BookDetailModel(
                                        id: bookId,
                                        title: title,
                                        author: actorName.isEmpty
                                            ? _displayName
                                            : actorName,
                                        description: msg,
                                        statusText: '',
                                        rating: 0,
                                        genre: '',
                                        cta: 'Read now',
                                        coverPath: cover,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.apiService.resolveAssetUrl(cover),
                            width: 72,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Reviews ─────────────────────────────────────────────

  Widget _buildMyActivityTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await widget.apiService.fetchMyActivity();
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.apiService.fetchMyActivity(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 40),
                Center(
                  child: Text(
                    'No activity yet',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(height: 8),
                Center(
                  child: Text(
                    'Likes, comments, reviews, follows, shares and saves you make will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF888888)),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = rows[i];
              final type = (n['type'] ?? '').toString();
              final title = (n['title'] ?? 'Activity').toString();
              final message = (n['message'] ?? '').toString();
              final when = (n['created_at'] ?? '').toString();
              final bookId = (n['book_id'] as num?)?.toInt() ?? 0;
              final cover = (n['cover_path'] ?? '').toString();
              IconData icon = Icons.notifications;
              if (type == 'like') icon = Icons.favorite;
              if (type == 'review') icon = Icons.star;
              if (type == 'follow') icon = Icons.person_add_alt_1;
              if (type == 'save') icon = Icons.bookmark;
              if (type == 'comment') icon = Icons.chat_bubble_outline;
              if (type == 'share') icon = Icons.ios_share;

              Widget leading;
              if (cover.isNotEmpty) {
                final url = widget.apiService.resolveAssetUrl(cover);
                leading = ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 48,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 64,
                      color: const Color(0xFFEDE9FE),
                      child: Icon(icon, color: const Color(0xFF6C3CE1), size: 20),
                    ),
                  ),
                );
              } else {
                leading = CircleAvatar(
                  backgroundColor: const Color(0xFFEDE9FE),
                  child: Icon(icon, color: const Color(0xFF6C3CE1), size: 20),
                );
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: leading,
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  [if (message.isNotEmpty) message, if (when.isNotEmpty) when].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: bookId > 0
                    ? const Icon(Icons.chevron_right, size: 20)
                    : null,
                onTap: bookId <= 0
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StoryDetailScreen(
                              apiService: widget.apiService,
                              book: BookDetailModel(
                                id: bookId,
                                title: title.replaceFirst(RegExp(r'^You (liked|reviewed|commented on|saved|shared)\s+'), ''),
                                author: '',
                                description: message,
                                statusText: '',
                                rating: 0,
                                genre: '',
                                cta: 'Read Now',
                                coverPath: cover,
                              ),
                            ),
                          ),
                        );
                      },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const Center(
        child: Text(
          'No reviews on your stories yet',
          style: TextStyle(color: muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _reviews.length,
      separatorBuilder: (context, index) => const Divider(height: 28),
      itemBuilder: (context, i) {
        final r = _reviews[i];
        final bookMap = (r['book'] is Map)
            ? Map<String, dynamic>.from(r['book'] as Map)
            : <String, dynamic>{};
        final bookTitle = _s(
          r['book_title'] ?? bookMap['title'] ?? r['title'] ?? 'Story',
        );
        final author = _s(
          r['reviewer_name'] ??
              r['book_author'] ??
              bookMap['author'] ??
              r['author'] ??
              '',
        );
        final cover = _s(
          r['cover_path'] ?? bookMap['cover_path'] ?? r['book_cover'] ?? '',
        );
        final bid = _asInt(
          r['book_id'] ?? bookMap['id'] ?? r['story_id'] ?? r['id'],
        );
        final stars = _asInt(r['rating'] ?? r['stars'] ?? 0);
        final plot = _asInt(r['plot_score'] ?? r['plot'] ?? stars);
        final writing = _asInt(
          r['writing_score'] ?? r['writing_style'] ?? stars,
        );
        final grammar = _asInt(r['grammar_score'] ?? r['grammar'] ?? stars);
        final headline = _s(r['headline'] ?? r['reviewer_name'] ?? '');
        final body = _s(
          r['body'] ?? r['comment'] ?? r['review'] ?? r['text'] ?? '',
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: cover.isNotEmpty
                      ? Image.network(
                          widget.apiService.resolveAssetUrl(cover),
                          width: 40,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(width: 40, height: 56, color: cardBg),
                        )
                      : Container(width: 40, height: 56, color: cardBg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (author.isNotEmpty)
                        Text(
                          author.isEmpty ? '' : 'Review by $author',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    final bid = _asInt(r['book_id']);
                    if (bid <= 0) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: widget.apiService,
                          book: BookDetailModel(
                            id: bid,
                            title: bookTitle,
                            author: author,
                            description: body,
                            statusText: '',
                            rating: stars.toDouble(),
                            genre: '',
                            cta: 'Read now',
                            coverPath: cover,
                          ),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 32),
                    side: const BorderSide(color: border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Read', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    Icons.bookmark_border,
                    size: 20,
                    color: muted,
                  ),
                  onPressed: () => _saveBookToReadingList(bid),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (j) {
                return Icon(
                  j < stars ? Icons.star : Icons.star_border,
                  size: 18,
                  color: const Color(0xFFF5A623),
                );
              }),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                _scoreChip('Plot $plot'),
                _scoreChip('Writing Style $writing'),
                _scoreChip('Grammar & Punctuation $grammar'),
              ],
            ),
            if (headline.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                headline,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF3A3A3A),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _scoreChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Owns its own TextEditingController so dispose is safe (no parent crash).
class _WallComposeSheet extends StatefulWidget {
  const _WallComposeSheet({required this.username, required this.apiService});
  final String username;
  final ApiService apiService;

  @override
  State<_WallComposeSheet> createState() => _WallComposeSheetState();
}

class _WallComposeSheetState extends State<_WallComposeSheet> {
  late final TextEditingController _ctrl;
  List<Map<String, dynamic>> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _suggestBooks(String value) async {
    final match = RegExp(r'@([^\s@]*)$').firstMatch(value);
    if (match == null || match.group(1)!.isEmpty) {
      if (mounted) setState(() => _suggestions = const []);
      return;
    }
    final query = match.group(1)!;
    final rows = await widget.apiService.searchStories(query: query);
    if (!mounted || _ctrl.text != value) return;
    setState(() => _suggestions = rows.take(5).toList());
  }

  void _selectBook(Map<String, dynamic> book) {
    final match = RegExp(r'@([^\s@]*)$').firstMatch(_ctrl.text);
    if (match == null) return;
    final title = (book['title'] ?? '').toString().trim();
    if (title.isEmpty) return;
    final replacement = '@[$title] ';
    _ctrl.value = _ctrl.value.copyWith(
      text: _ctrl.text.replaceRange(match.start, match.end, replacement),
      selection: TextSelection.collapsed(
        offset: match.start + replacement.length,
      ),
    );
    setState(() => _suggestions = const []);
  }

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFF6C3CE1);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Write something to ${widget.username}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            autofocus: true,
            onChanged: _suggestBooks,
            decoration: const InputDecoration(
              hintText: 'Say something…',
              border: OutlineInputBorder(),
            ),
          ),
          if (_suggestions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final book = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.menu_book_outlined, size: 18),
                    title: Text(book['title']?.toString() ?? ''),
                    subtitle: Text(book['author']?.toString() ?? ''),
                    onTap: () => _selectBook(book),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brand,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, _ctrl.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}

class _WallPostText extends StatelessWidget {
  const _WallPostText({required this.body, required this.apiService});

  final String body;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    final parts = RegExp(r'(@\[[^\]]+\]|@[A-Za-z0-9_-]+)').allMatches(body);
    if (parts.isEmpty) {
      return Text(body, style: const TextStyle(fontSize: 14, height: 1.35));
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in parts) {
      if (match.start > cursor)
        spans.add(TextSpan(text: body.substring(cursor, match.start)));
      final token = match.group(0)!;
      final query = token.startsWith('@[')
          ? token.substring(2, token.length - 1)
          : token.substring(1);
      final displayToken = token.startsWith('@[')
          ? '@${token.substring(2, token.length - 1)}'
          : token;
      spans.add(
        TextSpan(
          text: displayToken,
          style: const TextStyle(
            color: Color(0xFF6C3CE1),
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final rows = await apiService.searchStories(query: query);
              if (rows.isEmpty || !context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StoryDetailScreen(
                    apiService: apiService,
                    book: BookDetailModel.fromMap(rows.first),
                  ),
                ),
              );
            },
        ),
      );
      cursor = match.end;
    }
    if (cursor < body.length) spans.add(TextSpan(text: body.substring(cursor)));
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(
          context,
        ).style.copyWith(fontSize: 14, height: 1.35),
        children: spans,
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

/// Inkitt-style multi-cover collage for reading list cards (2x2 grid of covers).
class _ReadingListCollage extends StatelessWidget {
  const _ReadingListCollage({required this.covers});

  final List<String> covers;

  @override
  Widget build(BuildContext context) {
    final urls = covers.take(4).toList();
    if (urls.length == 1) {
      return Image.network(
        urls.first,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Container(color: const Color(0xFFF1F5F9)),
      );
    }
    // 2x2 grid
    while (urls.length < 4) {
      urls.add('');
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cell(urls[0])),
              const SizedBox(width: 2),
              Expanded(child: _cell(urls[1])),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cell(urls[2])),
              const SizedBox(width: 2),
              Expanded(child: _cell(urls[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(String url) {
    if (url.isEmpty) {
      return Container(color: const Color(0xFFE8EEF5));
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => Container(color: const Color(0xFFE8EEF5)),
    );
  }
}


class _ProfileStatChip extends StatelessWidget {
  const _ProfileStatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6C3CE1)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8A8F98),
            ),
          ),
        ],
      ),
    );
  }
}
