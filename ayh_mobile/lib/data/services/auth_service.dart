import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/user.dart';
import '../models/donor_profile.dart';
import 'storage_service.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storage = StorageService();

  /// Short timeouts while probing hosts so a dead port does not block 15s each.
  void _beginProbeTimeouts() {
    _apiClient.dio.options.connectTimeout = const Duration(seconds: 5);
    _apiClient.dio.options.receiveTimeout = const Duration(seconds: 8);
  }

  void _restoreDefaultTimeouts() {
    _apiClient.dio.options.connectTimeout = const Duration(seconds: 15);
    _apiClient.dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final hosts = await ApiConstants.candidateBaseUrls();
    DioException? lastConnectionError;
    _beginProbeTimeouts();

    try {
      for (final baseUrl in hosts) {
        _apiClient.setBaseUrl(baseUrl);
        try {
          final response = await _apiClient.post(
            ApiConstants.login,
            data: {
              'username': username.trim(),
              'password': password,
            },
          );

          if (response.statusCode == 200) {
            await _storage.saveApiBaseUrl(baseUrl);
            final data = response.data;
            return {
              'success': true,
              'access': data['access'],
              'refresh': data['refresh'],
              'user': User.fromJson(data['user']),
              'has_donor_profile': data['has_donor_profile'] ?? false,
              'donor_profile_complete': data['donor_profile_complete'] ?? false,
              'donor_profile': data['donor_profile'] != null
                  ? DonorProfile.fromJson(data['donor_profile'])
                  : null,
            };
          }
          return {'success': false, 'error': 'Login failed'};
        } on DioException catch (e) {
          if (e.response?.statusCode == 401) {
            final msg = _getErrorMessage(e.response?.data);
            return {
              'success': false,
              'error': msg ?? 'Invalid username or password',
            };
          }
          if (e.response?.statusCode == 429) {
            final msg = _getErrorMessage(e.response?.data);
            return {
              'success': false,
              'error': msg ?? 'Too many attempts. Please try again later.',
            };
          }
          if (_isConnectionFailure(e)) {
            lastConnectionError = e;
            continue;
          }
          final msg = _getErrorMessage(e.response?.data);
          return {'success': false, 'error': msg ?? 'Login failed'};
        } catch (e) {
          return {'success': false, 'error': 'Login failed. Please try again.'};
        }
      }

      if (lastConnectionError != null) {
        return {
          'success': false,
          'error':
              'Cannot reach server. From AYH run: '
              'python manage.py runserver 0.0.0.0:8000 '
              '(and adb reverse tcp:8000 tcp:8000 for each emulator)',
        };
      }

      return {'success': false, 'error': 'Login failed. Please try again.'};
    } finally {
      _restoreDefaultTimeouts();
    }
  }

  /// Exchange a Google ID token for Django JWTs (same shape as password login).
  Future<Map<String, dynamic>> loginWithGoogleIdToken(String idToken) async {
    final hosts = await ApiConstants.candidateBaseUrls();
    DioException? lastConnectionError;
    _beginProbeTimeouts();

    try {
      for (final baseUrl in hosts) {
        _apiClient.setBaseUrl(baseUrl);
        try {
          final response = await _apiClient.post(
            ApiConstants.googleAuth,
            data: {'id_token': idToken},
          );

          if (response.statusCode == 200) {
            await _storage.saveApiBaseUrl(baseUrl);
            final data = response.data;
            return {
              'success': true,
              'access': data['access'],
              'refresh': data['refresh'],
              'user': User.fromJson(data['user']),
              'has_donor_profile': data['has_donor_profile'] ?? false,
              'donor_profile_complete': data['donor_profile_complete'] ?? false,
              'donor_profile': data['donor_profile'] != null
                  ? DonorProfile.fromJson(data['donor_profile'])
                  : null,
              'created': data['created'] ?? false,
              'message': data['message'],
            };
          }
          return {
            'success': false,
            'error': _getErrorMessage(response.data) ?? 'Google Sign-In failed',
          };
        } on DioException catch (e) {
          if (_isConnectionFailure(e)) {
            lastConnectionError = e;
            continue;
          }
          return {
            'success': false,
            'error':
                _getErrorMessage(e.response?.data) ?? 'Google Sign-In failed',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Google Sign-In failed. Please try again.',
          };
        }
      }

      if (lastConnectionError != null) {
        return {
          'success': false,
          'error':
              'Cannot reach server. Run: python manage.py runserver 0.0.0.0:8000',
        };
      }
      return {'success': false, 'error': 'Google Sign-In failed'};
    } finally {
      _restoreDefaultTimeouts();
    }
  }

  static bool _isConnectionFailure(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.message?.contains('took longer') == true;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String? firstName,
    String? lastName,
  }) async {
    final hosts = await ApiConstants.candidateBaseUrls();
    DioException? lastConnectionError;
    _beginProbeTimeouts();

    try {
      for (final baseUrl in hosts) {
        _apiClient.setBaseUrl(baseUrl);
        try {
          final response = await _apiClient.post(
            ApiConstants.register,
            data: {
              'username': username.trim(),
              'email': email.trim(),
              'password': password,
              'password_confirm': passwordConfirm,
              'first_name': firstName ?? '',
              'last_name': lastName ?? '',
            },
          );

          if (response.statusCode == 201) {
            await _storage.saveApiBaseUrl(baseUrl);
            final data = response.data;
            return {
              'success': true,
              'access': data['access'],
              'refresh': data['refresh'],
              'user': User.fromJson(data['user']),
              'message': data['message'],
            };
          }
          final msg = _getErrorMessage(response.data);
          return {'success': false, 'error': msg ?? 'Registration failed'};
        } on DioException catch (e) {
          if (_isConnectionFailure(e)) {
            lastConnectionError = e;
            continue;
          }
          final msg = _getErrorMessage(e.response?.data);
          return {'success': false, 'error': msg ?? 'Registration failed'};
        }
      }

      if (lastConnectionError != null) {
        return {
          'success': false,
          'error':
              'Cannot reach server. Run: python manage.py runserver 0.0.0.0:8000',
        };
      }
      return {'success': false, 'error': 'Registration failed'};
    } finally {
      _restoreDefaultTimeouts();
    }
  }

  static String? _getErrorMessage(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is Map) {
      if (data['error'] != null) return data['error'].toString();
      if (data['detail'] != null) {
        final d = data['detail'];
        if (d is String) return d;
        if (d is List && d.isNotEmpty) {
          return d.map((e) => e.toString()).join(' ');
        }
      }
      for (final key in data.keys) {
        final v = data[key];
        if (v is List && v.isNotEmpty) {
          return v.map((e) => e.toString()).join(' ');
        }
        if (v is String) return v;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final hosts = await ApiConstants.candidateBaseUrls();
    DioException? lastConnectionError;
    _beginProbeTimeouts();

    try {
      for (final baseUrl in hosts) {
        _apiClient.setBaseUrl(baseUrl);
        try {
          final response = await _apiClient.post(
            ApiConstants.passwordReset,
            data: {'email': email.trim()},
          );

          if (response.statusCode == 200) {
            await _storage.saveApiBaseUrl(baseUrl);
            final data = response.data;
            return {
              'success': true,
              'message': data['message'] ??
                  'If an account exists for this email, a password reset link has been sent.',
            };
          }
          return {
            'success': false,
            'error': _getErrorMessage(response.data) ?? 'Request failed',
          };
        } on DioException catch (e) {
          if (_isConnectionFailure(e)) {
            lastConnectionError = e;
            continue;
          }
          return {
            'success': false,
            'error': _getErrorMessage(e.response?.data) ?? 'Request failed',
          };
        } catch (e) {
          return {'success': false, 'error': 'Request failed. Please try again.'};
        }
      }

      if (lastConnectionError != null) {
        return {
          'success': false,
          'error':
              'Cannot reach server. From AYH run: '
              'python manage.py runserver 0.0.0.0:8000',
        };
      }
      return {'success': false, 'error': 'Request failed. Please try again.'};
    } finally {
      _restoreDefaultTimeouts();
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _apiClient.get(ApiConstants.currentUser);

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': true,
          'user': User.fromJson(data['user']),
          'has_donor_profile': data['has_donor_profile'] ?? false,
          'donor_profile_complete': data['donor_profile_complete'] ?? false,
          'donor_profile': data['donor_profile'] != null
              ? DonorProfile.fromJson(data['donor_profile'])
              : null,
        };
      }
      return {'success': false, 'error': 'Failed to get user'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> logout(String refreshToken) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.logout,
        data: {'refresh': refreshToken},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
