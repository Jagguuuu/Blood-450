import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiConstants {
  /// Production Django API on Vercel.
  /// Override: `--dart-define=API_BASE_URL=https://your-app.vercel.app/api/`
  static const String _apiBaseUrlFromEnv =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Default production host used for release APK builds when API_BASE_URL is omitted.
  static const String _defaultVercelApiBaseUrl =
      'https://blood-450-gqkc.vercel.app/api/';

  /// Physical device on Wi‑Fi: `flutter run --dart-define=API_HOST=192.168.1.10`
  static const String _apiHostFromEnv =
      String.fromEnvironment('API_HOST', defaultValue: '');
  static const String _apiPortFromEnv =
      String.fromEnvironment('API_PORT', defaultValue: '8000');

  static const String _prefsKeyApiBaseUrl = 'api_base_url';

  static String? _cachedBaseUrl;

  /// Android emulator → host PC localhost. iOS sim / desktop → 127.0.0.1.
  /// Release / explicit API_BASE_URL → Vercel.
  static String get baseUrl => _cachedBaseUrl ?? _defaultBaseUrl();

  static String _normalizeApiBase(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  static String _defaultBaseUrl() {
    final fromEnv = _apiBaseUrlFromEnv.trim();
    if (fromEnv.isNotEmpty) {
      return _normalizeApiBase(fromEnv);
    }

    // Release APK always talks to Vercel unless API_BASE_URL/API_HOST overrides.
    if (kReleaseMode) {
      return _defaultVercelApiBaseUrl;
    }

    final envHost = _apiHostFromEnv.trim();
    final envPort = _apiPortFromEnv.trim().isEmpty ? '8000' : _apiPortFromEnv.trim();
    if (envHost.isNotEmpty) {
      if (envHost.startsWith('http://') || envHost.startsWith('https://')) {
        return _normalizeApiBase('$envHost/api');
      }
      return 'http://$envHost:$envPort/api/';
    }

    if (kIsWeb) return 'http://127.0.0.1:$envPort/api/';
    if (Platform.isAndroid) {
      // 10.0.2.2 is the emulator's alias for the host machine's 127.0.0.1:8000
      return 'http://10.0.2.2:$envPort/api/';
    }
    return 'http://127.0.0.1:$envPort/api/';
  }

  /// Drop stale LAN IPs / localhost-only ports saved from old sessions.
  static String? normalizeSavedUrl(String? saved) {
    if (saved == null || saved.isEmpty) return null;

    final envHost = _apiHostFromEnv.trim();
    if (envHost.isNotEmpty) return saved;

    if (kReleaseMode) return saved;

    final lower = saved.toLowerCase();
    if (!kIsWeb && Platform.isAndroid) {
      // Port 8005 is often bound to 127.0.0.1 only → unreachable via 10.0.2.2.
      // Prefer the all-interfaces server on 8000 (or 127.0.0.1 after adb reverse).
      if (lower.contains(':8005')) {
        return 'http://10.0.2.2:8000/api/';
      }
      if (lower.contains('192.168.') || lower.contains('localhost')) {
        return 'http://10.0.2.2:8000/api/';
      }
    }
    return saved;
  }

  static Future<void> loadSavedBaseUrl(
    Future<String?> Function() readSaved,
  ) async {
    final saved = await readSaved();
    final normalized = normalizeSavedUrl(saved);
    if (normalized != null && normalized.isNotEmpty) {
      _cachedBaseUrl = normalized.endsWith('/') ? normalized : '$normalized/';
    }
  }

  static void setWorkingBaseUrl(String url) {
    _cachedBaseUrl = url.endsWith('/') ? url : '$url/';
  }

  static String get prefsKeyApiBaseUrl => _prefsKeyApiBaseUrl;

  /// Ordered hosts for login/register probe (first success is saved).
  /// Android: prefer 10.0.2.2:8000, then 127.0.0.1:8000 (adb reverse), then 8005.
  static Future<List<String>> candidateBaseUrls() async {
    final seen = <String>{};
    final envPort =
        _apiPortFromEnv.trim().isEmpty ? '8000' : _apiPortFromEnv.trim();
    void add(String url) {
      if (url.isNotEmpty) {
        seen.add(url.endsWith('/') ? url : '$url/');
      }
    }

    final apiBase = _apiBaseUrlFromEnv.trim();
    if (apiBase.isNotEmpty) {
      add(_normalizeApiBase(apiBase));
      return seen.toList();
    }

    if (kReleaseMode) {
      add(_defaultVercelApiBaseUrl);
      return seen.toList();
    }

    final envHost = _apiHostFromEnv.trim();
    if (envHost.isNotEmpty) {
      if (envHost.startsWith('http://') || envHost.startsWith('https://')) {
        add(_normalizeApiBase('$envHost/api'));
      } else {
        add('http://$envHost:$envPort/api/');
      }
      return seen.toList();
    }

    if (!kIsWeb && Platform.isAndroid) {
      // Always try the all-interfaces Django port first.
      add('http://10.0.2.2:8000/api/');
      // Works when `adb reverse tcp:8000 tcp:8000` is set (multi-emulator).
      add('http://127.0.0.1:8000/api/');
      if (envPort != '8000') {
        add('http://10.0.2.2:$envPort/api/');
        add('http://127.0.0.1:$envPort/api/');
      }
      add('http://10.0.2.2:8005/api/');
      add('http://127.0.0.1:8005/api/');
    } else {
      add('http://127.0.0.1:8000/api/');
      if (envPort != '8000') {
        add('http://127.0.0.1:$envPort/api/');
      }
      add('http://127.0.0.1:8005/api/');
    }

    add(baseUrl);

    if (kReleaseMode) {
      return seen.toList();
    }

    return seen.toList();
  }

  static const String login = 'auth/login/';
  static const String register = 'auth/register/';
  static const String googleAuth = 'auth/google/';
  static const String logout = 'auth/logout/';
  static const String currentUser = 'auth/me/';
  static const String tokenRefresh = 'auth/token/refresh/';
  static const String passwordReset = 'auth/password-reset/';

  /// Web OAuth client ID used as GoogleSignIn.serverClientId so the ID token
  /// `aud` matches Django GOOGLE_OAUTH_CLIENT_ID.
  /// Override with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` if needed.
  /// Never put the client secret in Flutter.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '477230798600-2ji7shhdnkmkra920o68j6kf8398roe3.apps.googleusercontent.com',
  );

  static const String donors = 'donors/';
  static const String donorMe = 'donors/me/';
  static const String donorUpdateMe = 'donors/update_me/';

  static const String bloodRequests = 'blood-requests/';
  static const String bloodRequestsActive = 'blood-requests/active/';
  static const String bloodRequestsMyRequests = 'blood-requests/my_requests/';

  static const String notifications = 'notifications/';
  static const String notificationMarkAllRead = 'notifications/mark_all_read/';

  static const String respond = 'respond/';
  static const String dashboard = 'dashboard/';

  static const String whatsappUnread = 'whatsapp/unread/';
  static const String whatsappConversations = 'whatsapp/conversations/';
  static String whatsappMessages(int conversationId) =>
      'whatsapp/conversations/$conversationId/messages/';
  static String whatsappSend(int conversationId) =>
      'whatsapp/conversations/$conversationId/send/';

  static const double defaultRadiusKm = 10.0;
  static const String whatsappBusinessNumber = '15556565019';
}
