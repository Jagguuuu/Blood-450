class ApiConstants {
  /// Production Django API (AWS).
  ///
  /// Override with:
  /// --dart-define=API_BASE_URL=http://65.2.20.185/api/
  static const String _apiBaseUrlFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Default host for debug + release when API_BASE_URL is omitted.
  /// Web login: http://65.2.20.185/accounts/login/
  /// Flutter API: http://65.2.20.185/api/
  static const String _defaultProductionApiBaseUrl =
      'http://65.2.20.185/api/';

  /// Physical device / custom host:
  /// flutter run --dart-define=API_HOST=192.168.1.10
  static const String _apiHostFromEnv = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static const String _apiPortFromEnv = String.fromEnvironment(
    'API_PORT',
    defaultValue: '8000',
  );

  static const String _prefsKeyApiBaseUrl = 'api_base_url';

  static String? _cachedBaseUrl;

  /// Default → AWS API. Override with API_BASE_URL / API_HOST.
  static String get baseUrl => _cachedBaseUrl ?? _defaultBaseUrl();

  static String _normalizeApiBase(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.endsWith('/')) return trimmed;
    // Concatenation avoids raw-string / interpolation edge cases in the analyzer.
    // ignore: prefer_interpolation_to_compose_strings
    return trimmed + '/';
  }

  static String _defaultBaseUrl() {
    final fromEnv = _apiBaseUrlFromEnv.trim();

    if (fromEnv.isNotEmpty) {
      return _normalizeApiBase(fromEnv);
    }

    final envHost = _apiHostFromEnv.trim();

    if (envHost.isNotEmpty) {
      if (envHost.startsWith('http://') || envHost.startsWith('https://')) {
        return _normalizeApiBase('$envHost/api');
      }

      final envPort = _apiPortFromEnv.trim().isEmpty
          ? '80'
          : _apiPortFromEnv.trim();
      if (envPort == '80' || envPort == '443') {
        final scheme = envPort == '443' ? 'https' : 'http';
        return '$scheme://$envHost/api/';
      }
      return 'http://$envHost:$envPort/api/';
    }

    return _defaultProductionApiBaseUrl;
  }

  /// Drop stale LAN / localhost / old Render URLs saved from prior sessions.
  static String? normalizeSavedUrl(String? saved) {
    if (saved == null || saved.isEmpty) return null;

    final envHost = _apiHostFromEnv.trim();
    if (envHost.isNotEmpty) return saved;

    if (_apiBaseUrlFromEnv.trim().isNotEmpty) {
      return _normalizeApiBase(_apiBaseUrlFromEnv);
    }

    final lower = saved.toLowerCase();

    if (lower.contains('10.0.2.2') ||
        lower.contains('127.0.0.1') ||
        lower.contains('localhost') ||
        lower.contains('192.168.') ||
        lower.contains('onrender.com')) {
      return _defaultProductionApiBaseUrl;
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

  /// Ordered hosts for login/register probe.
  /// Default: AWS http://65.2.20.185/api/
  static Future<List<String>> candidateBaseUrls() async {
    final seen = <String>{};

    final envPort = _apiPortFromEnv.trim().isEmpty
        ? '8000'
        : _apiPortFromEnv.trim();

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

    final envHost = _apiHostFromEnv.trim();

    if (envHost.isNotEmpty) {
      if (envHost.startsWith('http://') || envHost.startsWith('https://')) {
        add(_normalizeApiBase('$envHost/api'));
      } else if (envPort == '80' || envPort == '443') {
        final scheme = envPort == '443' ? 'https' : 'http';
        add('$scheme://$envHost/api/');
      } else {
        add('http://$envHost:$envPort/api/');
      }

      return seen.toList();
    }

    add(_defaultProductionApiBaseUrl);
    add(baseUrl);

    return seen.toList();
  }

  // ---------------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------------

  static const String login = 'auth/login/';
  static const String register = 'auth/register/';
  static const String googleAuth = 'auth/google/';
  static const String logout = 'auth/logout/';
  static const String currentUser = 'auth/me/';
  static const String tokenRefresh = 'auth/token/refresh/';
  static const String passwordReset = 'auth/password-reset/';

  /// Web OAuth client ID used as GoogleSignIn.serverClientId
  /// so the ID token `aud` matches Django GOOGLE_OAUTH_CLIENT_ID.
  ///
  /// Override with:
  /// --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  ///
  /// Never put the client secret in Flutter.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '477230798600-2ji7shhdnkmkra920o68j6kf8398roe3.apps.googleusercontent.com',
  );

  // ---------------------------------------------------------------------------
  // DONORS
  // ---------------------------------------------------------------------------

  static const String donors = 'donors/';
  static const String donorMe = 'donors/me/';
  static const String donorUpdateMe = 'donors/update_me/';

  // ---------------------------------------------------------------------------
  // LOCATION
  // ---------------------------------------------------------------------------

  static const String locationResolve = 'location/resolve/';

  // ---------------------------------------------------------------------------
  // BLOOD REQUESTS
  // ---------------------------------------------------------------------------

  static const String bloodRequests = 'blood-requests/';
  static const String bloodRequestsActive = 'blood-requests/active/';
  static const String bloodRequestsMyRequests = 'blood-requests/my_requests/';

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------

  static const String notifications = 'notifications/';
  static const String notificationMarkAllRead = 'notifications/mark_all_read/';

  // ---------------------------------------------------------------------------
  // DONOR RESPONSE
  // ---------------------------------------------------------------------------

  static const String respond = 'respond/';

  // ---------------------------------------------------------------------------
  // DASHBOARD / LEADERBOARD
  // ---------------------------------------------------------------------------

  static const String dashboard = 'dashboard/';
  static const String leaderboard = 'leaderboard/';

  // ---------------------------------------------------------------------------
  // WHATSAPP
  // ---------------------------------------------------------------------------

  static const String whatsappUnread = 'whatsapp/unread/';
  static const String whatsappConversations = 'whatsapp/conversations/';

  static String whatsappMessages(int conversationId) =>
      'whatsapp/conversations/$conversationId/messages/';

  static String whatsappSend(int conversationId) =>
      'whatsapp/conversations/$conversationId/send/';

  // ---------------------------------------------------------------------------
  // CONFIG
  // ---------------------------------------------------------------------------

  static const double defaultRadiusKm = 10.0;

  static const String whatsappBusinessNumber = '15556565019';
}
