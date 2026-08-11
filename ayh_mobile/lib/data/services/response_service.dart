import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';

class ResponseService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> respondToRequest({
    required int bloodRequestId,
    required String response, // 'accepted' or 'rejected'
  }) async {
    try {
      final apiResponse = await _apiClient.post(
        ApiConstants.respond,
        data: {
          'blood_request_id': bloodRequestId,
          'response': response,
        },
      );

      if (apiResponse.statusCode == 200) {
        return {
          'success': true,
          'message': apiResponse.data['message'],
          'response': apiResponse.data['response'],
        };
      }
      return {
        'success': false,
        'error': _extractError(apiResponse.data) ?? 'Failed to respond',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _extractError(e.response?.data) ??
            (e.message?.isNotEmpty == true
                ? e.message!
                : 'Failed to respond'),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static String? _extractError(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is Map) {
      final err = data['error'] ?? data['detail'];
      if (err is String) return err;
      if (err is List && err.isNotEmpty) {
        return err.map((e) => e.toString()).join(' ');
      }
    }
    return null;
  }
}
