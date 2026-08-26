import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService();

  String? _authToken;

  String? get authTokenForPersistence => _authToken;

  /// Last successful bootstrap — survive sleep / failed refresh (never show empty app).
  static AppBootstrap? _cachedBootstrap;
  static const _diskBootstrapKey = 'novelhub_bootstrap_json_v1';

  Future<AppBootstrap?> loadDiskBootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskBootstrapKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final boot = AppBootstrap.fromMap(Map<String, dynamic>.from(decoded));
      if (boot.discoverBooks.isEmpty && boot.recentlyUpdated.isEmpty) return null;
      _cachedBootstrap = boot;
      return boot;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDiskBootstrap(Map<String, dynamic> raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_diskBootstrapKey, jsonEncode(raw));
    } catch (_) {}
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Production backend (Vercel). Override anytime with:
  ///   --dart-define=API_BASE_URL=https://other-host.example
  static const String _productionApiBaseUrl =
      'https://novel-v7.vercel.app';

  static const String _overrideApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  String get _baseUrl {
    if (_overrideApiBaseUrl.isNotEmpty) {
      return _overrideApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }

    if (kDebugMode) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        const emulatorUrl = 'http://10.0.2.2:8000';
        debugPrint(
          'ApiService: Android debug default base URL is $emulatorUrl.\n'
          'Physical device? pass --dart-define=API_BASE_URL=http://<PC_IP>:8000\n'
          'To hit production from debug: --dart-define=API_BASE_URL=https://novel-v7.vercel.app',
        );
        return emulatorUrl;
      }
      return 'http://127.0.0.1:8000';
    }

    // Release APK → Vercel backend
    return _productionApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  }

  Map<String, String> get _authHeaders {
    if (_authToken == null || _authToken!.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $_authToken'};
  }

  /// Host fallback: only used in release when the primary host fails.
  /// In debug we never fall back to production — that was causing Google
  /// "Not Found" and empty Discover when local backend was down or misconfigured.
  Future<http.Response> _requestWithHostFallback(
    Future<http.Response> Function(String baseUrl) request,
    Duration timeout,
  ) async {
    try {
      return await request(_baseUrl).timeout(timeout);
    } on http.ClientException {
      if (kDebugMode || _baseUrl == _productionApiBaseUrl) rethrow;
      return request(_productionApiBaseUrl).timeout(timeout);
    } on TimeoutException {
      if (kDebugMode || _baseUrl == _productionApiBaseUrl) rethrow;
      return request(_productionApiBaseUrl).timeout(timeout);
    }
  }

  Future<http.Response> _get(
    String path, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _requestWithHostFallback(
      (baseUrl) => http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders),
      timeout,
    );
  }

  String resolveAssetUrl(String path) {
    if (path.isEmpty) return path;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    // Durable DB-backed media (survives Vercel cold starts)
    if (trimmed.startsWith('/api/media/')) {
      return '$_baseUrl$trimmed';
    }
    // Strip query/hash noise if present
    final clean = trimmed.split('?').first.split('#').first;
    if (clean.contains('story_card_images/') ||
        clean.contains('/uploads/') ||
        clean.contains('\\uploads\\')) {
      final filename = clean.split('/').last.split('\\').last;
      if (filename.isNotEmpty) {
        return '$_baseUrl/uploads/$filename';
      }
    }
    if (!clean.startsWith('/')) {
      if (clean.startsWith('uploads/')) return '$_baseUrl/$clean';
      return '$_baseUrl/uploads/$clean';
    }
    // Absolute path like /uploads/foo.jpg
    if (clean.startsWith('/uploads/')) return '$_baseUrl$clean';
    final filename = clean.split('/').last;
    if (filename.contains('.') && !clean.contains('/api/')) {
      return '$_baseUrl/uploads/$filename';
    }
    return '$_baseUrl$clean';
  }

  Future<http.Response> _post(
    String path,
    Object body, {
    Duration timeout = const Duration(seconds: 45),
  }) {
    return _requestWithHostFallback(
      (baseUrl) => http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json', ..._authHeaders},
        body: jsonEncode(body),
      ),
      timeout,
    );
  }

  Future<http.Response> _put(
    String path,
    Object body, {
    Duration timeout = const Duration(seconds: 45),
  }) {
    return _requestWithHostFallback(
      (baseUrl) => http.put(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json', ..._authHeaders},
        body: jsonEncode(body),
      ),
      timeout,
    );
  }

  Future<http.Response> _delete(
    String path, {
    Duration timeout = const Duration(seconds: 45),
  }) {
    return _requestWithHostFallback(
      (baseUrl) =>
          http.delete(Uri.parse('$baseUrl$path'), headers: _authHeaders),
      timeout,
    );
  }

  void _ensureSuccessResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Backend request failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<AppBootstrap> fetchBootstrap() async {
    // Vercel cold start can exceed 45s once; retry once after warm-up.
    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _get(
          '/api/bootstrap',
          timeout: const Duration(seconds: 90),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final boot = AppBootstrap.fromMap(decoded);
            // Only cache non-empty home data so we never "stick" on blank shell
            if (boot.discoverBooks.isNotEmpty ||
                boot.recentlyUpdated.isNotEmpty) {
              _cachedBootstrap = boot;
              unawaited(_saveDiskBootstrap(decoded));
            }
            debugPrint(
              'bootstrap OK from $_baseUrl '
              'recently_updated=${boot.recentlyUpdated.length} '
              'discover=${boot.discoverBooks.length}',
            );
            return boot;
          }
        }
        debugPrint(
          'bootstrap HTTP ${response.statusCode} from $_baseUrl: '
          '${response.body.length > 300 ? response.body.substring(0, 300) : response.body}',
        );
        lastError = 'HTTP ${response.statusCode}';
      } catch (e, st) {
        lastError = e;
        debugPrint('bootstrap error (attempt $attempt) from $_baseUrl: $e');
        if (attempt == 1) {
          debugPrint('retrying bootstrap after cold-start...');
          await Future<void>.delayed(const Duration(seconds: 3));
          continue;
        }
        debugPrint('$st');
      }
    }
    debugPrint('bootstrap giving up: $lastError');
    // Prefer last good data over empty fallback (fixes blank app after sleep/comments)
    if (_cachedBootstrap != null) {
      debugPrint('bootstrap: returning cached home data');
      return _cachedBootstrap!;
    }
    return AppBootstrap.fromMap(_fallbackData);
  }

  Future<String> fetchContentVersion() async {
    try {
      final response = await _get(
        '/api/content/version',
        timeout: const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return payload['value']?.toString() ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<Map<String, dynamic>> fetchMe() async {
    try {
      final response = await _get(
        '/api/me',
        timeout: const Duration(seconds: 90),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  /// Raises on 401/403 so AuthService can force logout after ban/suspend.
  Future<Map<String, dynamic>> fetchMeStrict() async {
    final response = await _get('/api/me', timeout: const Duration(seconds: 90));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_authErrorBody(response));
  }

  Future<Map<String, dynamic>> fetchProfile(int userId) async {
    try {
      final response = await _get('/api/users/$userId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadWriterImage(
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/write/upload-image'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await request.send().timeout(
      const Duration(seconds: 45),
    );
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) {
      throw Exception('Sign in required to upload a cover image');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_authErrorBody(response));
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final path = (map['path'] ?? map['url'] ?? '').toString();
    if (path.isEmpty) {
      throw Exception('Cover upload returned empty path');
    }
    return map;
  }

  Future<Map<String, dynamic>> uploadUserImage(
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/me/upload-image'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await request.send().timeout(
      const Duration(seconds: 45),
    );
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) {
      throw Exception('Sign in required to upload a profile image');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_authErrorBody(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> payload) async {
    final response = await _put(
      '/api/me',
      payload,
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadSupportAttachment(
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/support/upload-attachment'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({String? tab}) async {
    try {
      final response = await _get(
        '/api/notifications${tab != null && tab.trim().isNotEmpty ? '?tab=${Uri.encodeComponent(tab)}' : ''}',
        timeout: const Duration(seconds: 7),
      );
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(
          payload['items'] as List<dynamic>,
        );
      }
    } catch (_) {}
    final fallback = (_fallbackData['notifications'] as List<dynamic>)
        .where((item) {
          if (tab == null || tab.trim().isEmpty) return true;
          return (item as Map<String, dynamic>)['tab'] == tab;
        })
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
    return fallback;
  }

  Future<void> submitSupportRequest(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/support/requests',
      payload,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to submit support request');
    }
  }

  Future<Map<String, dynamic>> verifyGoogleSignIn({
    String? idToken,
    String? accessToken,
  }) async {
    // Cold start + Google tokeninfo can exceed 12s on Vercel.
    final response = await _post('/api/auth/google', {
      'id_token': idToken,
      'access_token': accessToken,
    }, timeout: const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_authErrorBody(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _authErrorBody(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return 'Authentication failed (${response.statusCode})';
  }

  Future<Map<String, dynamic>> verifyEmailSignIn(
    String email, {
    required String password,
    String mode = 'login',
    String? displayName,
  }) async {
    final response = await _post('/api/auth/email', {
      'email': email,
      'password': password,
      'mode': mode,
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
    }, timeout: const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_authErrorBody(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyGuestSignIn({String? deviceId}) async {
    final response = await _post(
      '/api/auth/guest',
      <String, dynamic>{
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
      },
      timeout: const Duration(seconds: 45),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_authErrorBody(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> searchStories({
    String query = '',
    String genre = '',
    double minRating = 0,
  }) async {
    try {
      final uri = Uri(
        path: '/api/search',
        queryParameters: {
          'query': query,
          'genre': genre,
          'min_rating': minRating.toString(),
        },
      );
      final response = await _get('${uri.path}?${uri.query}');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (decoded is Map<String, dynamic>) {
        final items = decoded['items'];
        if (items is List) {
          return items
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return const <Map<String, dynamic>>[];
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  /// Search users/authors for Profile search chip.
  Future<List<Map<String, dynamic>>> searchUsers({String query = ''}) async {
    try {
      final q = Uri.encodeQueryComponent(query.trim());
      final response = await _get(
        '/api/users/search?query=$q',
        timeout: const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final items = payload['items'];
        if (items is List) {
          return items
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      if (payload is List) {
        return payload
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLibraryEntries() async {
    try {
      final response = await _get('/api/library');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchChatMessages() async {
    try {
      final response = await _get('/api/chat/messages');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyReviews() async {
    try {
      final response = await _get('/api/me/reviews');
      _ensureSuccessResponse(response);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['items'];
      if (items is! List) return const [];
      return items.map<Map<String, dynamic>>((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final book = m['book'];
        if (book is Map) {
          final b = Map<String, dynamic>.from(book);
          m['book_id'] = m['book_id'] ?? b['id'];
          m['book_title'] = m['book_title'] ?? b['title'];
          m['book_author'] = m['book_author'] ?? b['author'];
          m['cover_path'] = m['cover_path'] ?? b['cover_path'];
        }
        return m;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  
  /// Update signed-in user profile (onboarding + settings).
  Future<void> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/api/me/link-email',
      {'email': email, 'password': password},
      timeout: const Duration(seconds: 30),
    );
    _ensureSuccessResponse(response);
  }

  Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> payload) async {
    final response = await _put(
      '/api/me',
      payload,
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      return <String, dynamic>{'ok': true};
    }
  }

  Future<void> addLibraryEntry(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/library',
      payload,
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> updateLibraryEntry(int id, Map<String, dynamic> payload) async {
    final response = await _put(
      '/api/library/$id',
      payload,
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> deleteLibraryEntry(int id) async {
    final response = await _delete(
      '/api/library/$id',
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchReadingLists() async {
    try {
      final response = await _get('/api/reading-lists');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> createReadingList(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/reading-lists',
      payload,
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'ok': true};
    }
  }

  Future<Map<String, dynamic>> fetchReadingListDetail(int listId) async {
    final response = await _get('/api/reading-lists/$listId');
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Convenience: returns only the items array from a reading list detail.
  Future<List<Map<String, dynamic>>> fetchReadingListItems(int listId) async {
    final detail = await fetchReadingListDetail(listId);
    final items = detail['items'];
    if (items is List) {
      return List<Map<String, dynamic>>.from(items);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> addReadingListItem(int listId, int bookId) async {
    final response = await _post('/api/reading-lists/$listId/items', {
      'book_id': bookId,
    }, timeout: const Duration(seconds: 45));
    _ensureSuccessResponse(response);
  }

  Future<void> removeReadingListItem(int listId, int itemId) async {
    final response = await _delete(
      '/api/reading-lists/$listId/items/$itemId',
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> deleteReadingList(int listId) async {
    final response = await _delete(
      '/api/reading-lists/$listId',
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchWriterStories() async {
    try {
      final response = await _get(
        '/api/write/stories',
        timeout: const Duration(seconds: 30),
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('fetchWriterStories: auth required (${response.statusCode})');
        return const <Map<String, dynamic>>[];
      }
      if (response.statusCode != 200) {
        debugPrint('fetchWriterStories: HTTP ${response.statusCode}');
        return const <Map<String, dynamic>>[];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (decoded is Map) {
        final payload = Map<String, dynamic>.from(decoded);
        final items = payload['items'] ?? payload['stories'] ?? payload['data'];
        if (items is List) {
          return items
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return const <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('fetchWriterStories error: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> fetchStoryDetail(int storyId) async {
    final response = await _get('/api/books/$storyId');
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchBookReviews(int bookId) async {
    try {
      final response = await _get('/api/books/$bookId/reviews');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> createBookReview(
    int bookId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/api/books/$bookId/reviews',
      payload,
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
  }

  /// Live chapter comments (Inkitt reader bottom-sheet).
  Future<List<Map<String, dynamic>>> fetchChapterComments({
    required int bookId,
    required int chapterNumber,
  }) async {
    final payload = await fetchChapterCommentsPayload(
      bookId: bookId,
      chapterNumber: chapterNumber,
    );
    return List<Map<String, dynamic>>.from(
      (payload['items'] as List<dynamic>? ?? const <dynamic>[]),
    );
  }

  Future<Map<String, dynamic>> fetchChapterCommentsPayload({
    required int bookId,
    required int chapterNumber,
  }) async {
    try {
      final response = await _get(
        '/api/books/$bookId/chapters/$chapterNumber/comments',
      );
      if (response.statusCode != 200) {
        return const <String, dynamic>{
          'items': <Map<String, dynamic>>[],
          'paragraph_counts': <String, int>{},
        };
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return payload;
    } catch (_) {
      return const <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'paragraph_counts': <String, int>{},
      };
    }
  }

  Future<Map<String, dynamic>> postChapterComment({
    required int bookId,
    required int chapterNumber,
    required String body,
    int? paragraphIndex,
  }) async {
    final response = await _post(
      '/api/books/$bookId/chapters/$chapterNumber/comments',
      {
        'body': body,
        if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      },
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['item'] is Map) {
      return Map<String, dynamic>.from(payload['item'] as Map);
    }
    return payload;
  }

  /// Chapter-end reaction counts + current user's selections.
  Future<Map<String, dynamic>> fetchChapterReactions({
    required int bookId,
    required int chapterNumber,
  }) async {
    try {
      final response = await _get(
        '/api/books/$bookId/chapters/$chapterNumber/reactions',
      );
      if (response.statusCode != 200) {
        return const <String, dynamic>{'counts': {}, 'mine': []};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'counts': {}, 'mine': []};
    }
  }

  /// Toggle a reaction label for the current user.
  Future<Map<String, dynamic>> toggleChapterReaction({
    required int bookId,
    required int chapterNumber,
    required String label,
  }) async {
    final response = await _post(
      '/api/books/$bookId/chapters/$chapterNumber/reactions',
      {'label': label},
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchUserStories(int userId) async {
    try {
      final response = await _get('/api/users/$userId/stories');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserReadingLists(int userId) async {
    try {
      final response = await _get('/api/users/$userId/reading-lists');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserReviews(int userId) async {
    try {
      final response = await _get('/api/users/$userId/reviews');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserWall(int userId) async {
    try {
      final response = await _get('/api/users/$userId/wall');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }


  Future<List<Map<String, dynamic>>> fetchUserActivity(int userId) async {
    try {
      final response = await _get('/api/users/$userId/activity');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> postUserWall(int userId, String body, {String? imagePath}) async {
    final response = await _post('/api/users/$userId/wall', {
      'body': body,
      if (imagePath != null && imagePath.isNotEmpty) 'image_path': imagePath,
    });
    _ensureSuccessResponse(response);
  }
  Future<Map<String, dynamic>> likeWallPost(int postId) async {
    final response = await _post('/api/wall/$postId/like', {});
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'likes': (data['likes'] as num?)?.toInt() ?? 0,
      'liked': data['liked'] == true,
    };
  }

  Future<void> commentWallPost(int postId, String body) async {
    await _post('/api/wall/$postId/comment', {'body': body});
  }


  Future<Map<String, dynamic>> fetchBookLike(int bookId) async {
    try {
      final response = await _get('/api/books/$bookId/like');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{'liked': false, 'likes_count': 0};
  }

  Future<Map<String, dynamic>> likeBook(int bookId) async {
    final response = await _post(
      '/api/books/$bookId/like',
      const <String, dynamic>{},
      timeout: const Duration(seconds: 30),
    );
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unlikeBook(int bookId) async {
    final response = await _delete(
      '/api/books/$bookId/like',
      timeout: const Duration(seconds: 30),
    );
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> followAuthor(int authorId) async {
    final response = await _post(
      '/api/authors/$authorId/follow',
      const <String, dynamic>{},
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'ok': true};
    }
  }

  Future<Map<String, dynamic>> unfollowAuthor(int authorId) async {
    final response = await _delete(
      '/api/authors/$authorId/follow',
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'ok': true};
    }
  }

  Future<bool> fetchAuthorFollowing(int authorId) async {
    try {
      final response = await _get('/api/authors/$authorId/follow');
      if (response.statusCode != 200) return false;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return (payload['following'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch public book detail including tags and author_user_id.
  Future<Map<String, dynamic>?> fetchPublicBook(int bookId) async {
    try {
      final response = await _get('/api/books/$bookId');
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Distinct genres used across books (for genre dropdown).
  Future<List<String>> fetchGenres() async {
    try {
      final response = await _get('/api/genres');
      if (response.statusCode != 200) return const <String>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final items = payload['items'];
      if (items is! List) return const <String>[];
      return items
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  /// Create a genre so it appears in the shared dropdown for everyone.
  Future<String> createGenre(String name) async {
    final response = await _post(
      '/api/genres',
      {'name': name.trim()},
      timeout: const Duration(seconds: 60),
    );
    _ensureSuccessResponse(response);
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final n = (body['name'] as String?)?.trim();
      if (n != null && n.isNotEmpty) return n;
    } catch (_) {}
    return name.trim();
  }

  /// Publish a writer story (sets status_text to Published).
  Future<void> publishWriterStory(int storyId) async {
    final response = await _post(
      '/api/write/stories/$storyId/publish',
      const <String, dynamic>{},
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
  }

  /// Report a story. After 3 unique reporters, it surfaces in Admin → Reports.
  Future<Map<String, dynamic>> reportBook(int bookId, {String reason = ''}) async {
    final response = await _post(
      '/api/books/$bookId/report',
      {'reason': reason},
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'ok': true};
    }
  }

  /// List admin-managed hashtags (optional search query).
  Future<List<Map<String, dynamic>>> fetchTags({String? query}) async {
    try {
      final path = (query == null || query.trim().isEmpty)
          ? '/api/tags'
          : '/api/tags?q=${Uri.encodeQueryComponent(query.trim())}';
      final response = await _get(path);
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  /// Books that have the given hashtag.
  Future<List<Map<String, dynamic>>> fetchBooksByTag(String tagName) async {
    try {
      final encoded = Uri.encodeComponent(tagName.trim().replaceFirst('#', ''));
      final response = await _get('/api/tags/$encoded/books');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  /// Other public books by the same author (for "More Stories by Author").
  Future<List<Map<String, dynamic>>> fetchAuthorBooks(
    int authorId, {
    int? excludeBookId,
  }) async {
    try {
      final qs = excludeBookId != null ? '?exclude_id=$excludeBookId' : '';
      final response = await _get('/api/authors/$authorId/books$qs');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<int, bool>> fetchAuthorsFollowing(List<int> authorIds) async {
    if (authorIds.isEmpty) return <int, bool>{};
    final idsParam = authorIds.join(',');
    try {
      final response = await _get('/api/authors/follow?ids=$idsParam');
      if (response.statusCode != 200) return <int, bool>{};
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = Map<String, dynamic>.from(
        payload['following'] as Map<String, dynamic>? ?? {},
      );
      final Map<int, bool> out = {};
      raw.forEach((k, v) {
        final key = int.tryParse(k);
        if (key != null) out[key] = (v as bool?) ?? false;
      });
      return out;
    } catch (_) {
      return <int, bool>{};
    }
  }

  Future<int> createWriterStory(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/write/stories',
      payload,
      timeout: const Duration(seconds: 60),
    );
    _ensureSuccessResponse(response);
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['id'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> updateWriterStory(int id, Map<String, dynamic> payload) async {
    final response = await _put(
      '/api/write/stories/$id',
      payload,
      timeout: const Duration(seconds: 60),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> deleteWriterStory(int id) async {
    final response = await _delete(
      '/api/write/stories/$id',
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchStoryChapters(int storyId) async {
    try {
      final response = await _get(
        '/api/write/stories/$storyId/chapters',
        timeout: const Duration(seconds: 45),
      );
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<int?> createStoryChapter(
    int storyId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/api/write/stories/$storyId/chapters',
      payload,
      timeout: const Duration(seconds: 90),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['id'] as int?;
  }

  Future<void> updateStoryChapter(
    int chapterId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _put(
      '/api/write/chapters/$chapterId',
      payload,
      timeout: const Duration(seconds: 90),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchStoryChapterRevisions(
    int chapterId,
  ) async {
    try {
      final response = await _get(
        '/api/write/chapters/$chapterId/revisions',
        timeout: const Duration(seconds: 45),
      );
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> deleteStoryChapter(int chapterId) async {
    final response = await _delete(
      '/api/write/chapters/$chapterId',
      timeout: const Duration(seconds: 45),
    );
    _ensureSuccessResponse(response);
  }

  static final Map<String, dynamic> _fallbackData = <String, dynamic>{
    'discover_tabs': ['New', 'Popular', 'Fantasy', 'Fanfiction', 'Newsfeed'],
    'recently_updated': [],
    'recently_completed': [],
    'discover_books': [],
    'featured_book': {
      'id': 1,
      'title': 'Loading...',
      'author': '',
      'description': '',
      'status_text': '',
      'rating': 0,
      'genre': '',
      'cta': 'Read now',
    },
    'explore_topics': [],
    'library_entries': [],
    'write_screen': {
      'manage_tabs': ['Manage Stories', 'Analytics'],
      'story_tabs': ['Submitted', 'Drafts'],
      'filter_label': 'All stories',
      'sort_label': 'Recently Updated',
      'empty_title': "You haven't submitted any story yet",
      'empty_cta': 'Submit Stories',
    },
    'notifications': [],
    'menu_sections': [],
    'profile': {
      'display_name': 'Reader',
      'username': '@reader',
      'following': 0,
      'followers': 0,
      'blocked': 0,
      'chapters_read': 0,
      'social_karma': 0,
      'day_streak': 0,
      'reading_lists': [],
    },
    'achievements': [],
  };
}