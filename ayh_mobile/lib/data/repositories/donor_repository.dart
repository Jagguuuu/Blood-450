import '../services/donor_service.dart';
import '../services/storage_service.dart';
import '../models/donor_profile.dart';

/// Donor profile via Django API (Vercel). Supabase is the database on the server only.
class DonorRepository {
  final DonorService _donorService = DonorService();
  final StorageService _storageService = StorageService();

  Future<DonorProfile?> getMyProfile() async {
    final profile = await _donorService.getMyProfile();
    if (profile != null) {
      await _storageService.saveDonorProfile(profile);
    }
    return profile;
  }

  Future<DonorProfile?> createProfile({
    required String phone,
    required String bloodGroup,
    required bool isAvailable,
    double? lastLat,
    double? lastLng,
  }) async {
    final profile = await _donorService.createProfile(
      phone: phone,
      bloodGroup: bloodGroup,
      isAvailable: isAvailable,
      lastLat: lastLat,
      lastLng: lastLng,
    );

    if (profile != null) await _storageService.saveDonorProfile(profile);
    return profile;
  }

  Future<DonorProfile?> updateMyProfile({
    String? phone,
    String? bloodGroup,
    bool? isAvailable,
    double? lastLat,
    double? lastLng,
  }) async {
    final profile = await _donorService.updateMyProfile(
      phone: phone,
      bloodGroup: bloodGroup,
      isAvailable: isAvailable,
      lastLat: lastLat,
      lastLng: lastLng,
    );

    if (profile != null) await _storageService.saveDonorProfile(profile);
    return profile;
  }

  Future<DonorProfile?> updateMyLocation(double lat, double lng) async {
    return updateMyProfile(lastLat: lat, lastLng: lng);
  }

  Future<List<DonorProfile>> getAllDonors() async {
    return await _donorService.getAllDonors();
  }

  Future<DonorProfile?> getCachedProfile() async {
    return await _storageService.getDonorProfile();
  }
}
