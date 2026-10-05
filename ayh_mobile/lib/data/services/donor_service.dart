import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/donor_profile.dart';
import 'package:dio/dio.dart';

class DonorService {
  final ApiClient _apiClient = ApiClient();

  Future<DonorProfile?> getMyProfile() async {
    try {
      final response = await _apiClient.get(ApiConstants.donorMe);
      if (response.statusCode == 200) {
        return DonorProfile.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error getting profile: $e');
      return null;
    }
  }

  Future<DonorProfile?> createProfile({
    required String phone,
    required String bloodGroup,
    required bool isAvailable,
    double? lastLat,
    double? lastLng,
    DateTime? lastDonationDate,
  }) async {
    try {
      final data = <String, dynamic>{
        'phone': phone,
        'blood_group': bloodGroup,
        'is_available': isAvailable,
      };
      if (lastLat != null) {
        data['last_lat'] = double.parse(lastLat.toStringAsFixed(6));
      }
      if (lastLng != null) {
        data['last_lng'] = double.parse(lastLng.toStringAsFixed(6));
      }
      if (lastDonationDate != null) {
        data['last_donation_date'] =
            '${lastDonationDate.year.toString().padLeft(4, '0')}-'
            '${lastDonationDate.month.toString().padLeft(2, '0')}-'
            '${lastDonationDate.day.toString().padLeft(2, '0')}';
      }

      final response = await _apiClient.post(ApiConstants.donors, data: data);

      // 201 = created; 200 = completed existing incomplete profile (upsert).
      if (response.statusCode == 201 || response.statusCode == 200) {
        return DonorProfile.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error creating profile: $e');
      return null;
    }
  }

  Future<DonorProfile?> updateMyProfile({
    String? phone,
    String? bloodGroup,
    bool? isAvailable,
    double? lastLat,
    double? lastLng,
    DateTime? lastDonationDate,
    bool clearLastDonationDate = false,
    String? firstName,
    String? lastName,
    bool? donatedBefore,
  }) async {
    final data = <String, dynamic>{};
    if (phone != null) data['phone'] = phone;
    if (bloodGroup != null) data['blood_group'] = bloodGroup;
    if (isAvailable != null) data['is_available'] = isAvailable;
    if (lastLat != null) {
      data['last_lat'] = double.parse(lastLat.toStringAsFixed(6));
    }
    if (lastLng != null) {
      data['last_lng'] = double.parse(lastLng.toStringAsFixed(6));
    }
    if (clearLastDonationDate) {
      data['last_donation_date'] = null;
    } else if (lastDonationDate != null) {
      data['last_donation_date'] =
          '${lastDonationDate.year.toString().padLeft(4, '0')}-'
          '${lastDonationDate.month.toString().padLeft(2, '0')}-'
          '${lastDonationDate.day.toString().padLeft(2, '0')}';
    }
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (donatedBefore != null) data['donated_before'] = donatedBefore;

    try {
      final response = await _apiClient.patch(
        ApiConstants.donorUpdateMe,
        data: data,
      );

      if (response.statusCode == 200) {
        return DonorProfile.fromJson(response.data);
      }
      throw Exception(
        'Update failed (${response.statusCode}): ${_extractError(response.data)}',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = _extractError(e.response?.data);
      print('Error updating profile: status=$status body=$body err=$e');
      throw Exception(
        status != null
            ? 'Could not save profile (HTTP $status). $body'
            : 'Could not reach server. Check your connection.',
      );
    }
  }

  Future<List<DonorProfile>> getAllDonors() async {
    try {
      final response = await _apiClient.get(ApiConstants.donors);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => DonorProfile.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting donors: $e');
      return [];
    }
  }

  static String _extractError(dynamic data) {
    if (data == null) return '';
    if (data is String) return data;
    if (data is Map) {
      if (data['error'] != null) return data['error'].toString();
      if (data['detail'] != null) return data['detail'].toString();
      final parts = <String>[];
      data.forEach((key, value) {
        if (value is List) {
          parts.add('$key: ${value.join(', ')}');
        } else {
          parts.add('$key: $value');
        }
      });
      return parts.join('; ');
    }
    return data.toString();
  }
}
