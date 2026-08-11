import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/donor_profile.dart';

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
  }) async {
    try {
      final data = <String, dynamic>{
        'phone': phone,
        'blood_group': bloodGroup,
        'is_available': isAvailable,
      };
      if (lastLat != null) data['last_lat'] = lastLat;
      if (lastLng != null) data['last_lng'] = lastLng;

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
  }) async {
    try {
      final data = <String, dynamic>{};
      if (phone != null) data['phone'] = phone;
      if (bloodGroup != null) data['blood_group'] = bloodGroup;
      if (isAvailable != null) data['is_available'] = isAvailable;
      if (lastLat != null) data['last_lat'] = lastLat;
      if (lastLng != null) data['last_lng'] = lastLng;

      final response = await _apiClient.patch(
        ApiConstants.donorUpdateMe,
        data: data,
      );

      if (response.statusCode == 200) {
        return DonorProfile.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error updating profile: $e');
      return null;
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
}
