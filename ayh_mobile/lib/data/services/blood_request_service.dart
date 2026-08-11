import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/blood_request.dart' show BloodRequest, MatchedDonor;

class BloodRequestService {
  final ApiClient _apiClient = ApiClient();

  Future<List<BloodRequest>> getAllRequests() async {
    try {
      final response = await _apiClient.get(ApiConstants.bloodRequests);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => BloodRequest.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting requests: $e');
      return [];
    }
  }

  Future<List<BloodRequest>> getActiveRequests() async {
    try {
      final response = await _apiClient.get(ApiConstants.bloodRequestsActive);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => BloodRequest.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting active requests: $e');
      return [];
    }
  }

  Future<List<BloodRequest>> getMyRequests() async {
    try {
      final response = await _apiClient.get(
        ApiConstants.bloodRequestsMyRequests,
      );
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => BloodRequest.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting my requests: $e');
      return [];
    }
  }

  Future<BloodRequest?> getRequestDetail(int id) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.bloodRequests}$id/',
      );
      if (response.statusCode == 200) {
        return BloodRequest.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error getting request detail: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createRequest({
    required String bloodGroup,
    required int unitsNeeded,
    required String urgency,
    String? note,
    double? reqLat,
    double? reqLng,
    String? locationName,
    double? radiusKm,
  }) async {
    try {
      final data = <String, dynamic>{
        'blood_group': bloodGroup,
        'units_needed': unitsNeeded,
        'urgency': urgency,
        'note': note ?? '',
      };
      if (reqLat != null) data['req_lat'] = reqLat;
      if (reqLng != null) data['req_lng'] = reqLng;
      if (locationName != null && locationName.isNotEmpty) {
        data['location_name'] = locationName;
      }
      if (radiusKm != null) data['radius_km'] = radiusKm;

      final response = await _apiClient.post(
        ApiConstants.bloodRequests,
        data: data,
      );

      if (response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final bloodRequest = BloodRequest.fromJson(body['blood_request']);
        final matchedList = body['matched_donors'] as List<dynamic>?;
        final matchedDonors = matchedList != null
            ? matchedList
                  .map((d) => MatchedDonor.fromJson(d as Map<String, dynamic>))
                  .toList()
            : <MatchedDonor>[];
        return {
          'success': true,
          'message': body['message'],
          'blood_request': bloodRequest,
          'matched_donors': matchedDonors,
        };
      }
      return {'success': false, 'error': _extractError(response.data)};
    } on DioException catch (e) {
      final msg = _extractError(e.response?.data);
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static String _extractError(dynamic data) {
    if (data == null) return 'Failed to create request';
    if (data is String) return data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List) return detail.map((e) => e.toString()).join(' ');
      final firstKey = data.keys.isNotEmpty ? data.keys.first : null;
      if (firstKey != null && data[firstKey] is List) {
        return (data[firstKey] as List).map((e) => e.toString()).join(' ');
      }
    }
    return 'Failed to create request';
  }

  Future<bool> updateRequest(int id, {bool? isActive}) async {
    try {
      final response = await _apiClient.put(
        '${ApiConstants.bloodRequests}$id/',
        data: {'is_active': isActive},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating request: $e');
      return false;
    }
  }

  Future<bool> deleteRequest(int id) async {
    try {
      final response = await _apiClient.delete(
        '${ApiConstants.bloodRequests}$id/',
      );
      return response.statusCode == 204;
    } catch (e) {
      print('Error deleting request: $e');
      return false;
    }
  }
}
