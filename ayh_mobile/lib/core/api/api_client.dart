import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/services/storage_service.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = ApiConstants.baseUrl;

          final isAuthEndpoint =
              options.path.contains('auth/login/') ||
              options.path.contains('auth/register/') ||
              options.path.contains('auth/google/') ||
              options.path.contains('auth/token/refresh/');

          if (!isAuthEndpoint) {
            String? token = await _storage.read(key: 'access_token');
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          print('REQUEST[${options.method}] => ${options.baseUrl}${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('RESPONSE[${response.statusCode}] => DATA: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          print(
            'ERROR[${e.response?.statusCode}] => ${e.type} ${e.message} @ ${e.requestOptions.baseUrl}${e.requestOptions.path}',
          );

          final isAuthEndpoint =
              e.requestOptions.path.contains('auth/login/') ||
              e.requestOptions.path.contains('auth/register/') ||
              e.requestOptions.path.contains('auth/google/') ||
              e.requestOptions.path.contains('auth/token/refresh/');

          if (e.response?.statusCode == 401 && !isAuthEndpoint) {
            try {
              String? refreshToken = await _storage.read(key: 'refresh_token');

              if (refreshToken != null && refreshToken.isNotEmpty) {
                final response = await dio.post(
                  ApiConstants.tokenRefresh,
                  data: {'refresh': refreshToken},
                  options: Options(
                    headers: {
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                    },
                  ),
                );

                if (response.statusCode == 200) {
                  String newAccessToken = response.data['access'];
                  await _storage.write(
                    key: 'access_token',
                    value: newAccessToken,
                  );

                  e.requestOptions.headers['Authorization'] =
                      'Bearer $newAccessToken';
                  return handler.resolve(await dio.fetch(e.requestOptions));
                }
              }
            } catch (refreshError) {
              // Wipe JWT; AuthProvider.checkLoginStatus / logout clear prefs too.
              await _storage.deleteAll();
              try {
                await StorageService().clearAll();
              } catch (_) {}
            }
          }

          return handler.next(e);
        },
      ),
    );
  }

  void setBaseUrl(String url) {
    final normalized = url.endsWith('/') ? url : '$url/';
    dio.options.baseUrl = normalized;
    ApiConstants.setWorkingBaseUrl(normalized);
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await dio.delete(path);
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }
}
