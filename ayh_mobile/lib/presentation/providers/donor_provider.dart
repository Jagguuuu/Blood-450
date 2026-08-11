import 'package:flutter/foundation.dart';
import '../../data/repositories/donor_repository.dart';
import '../../data/models/donor_profile.dart';

class DonorProvider with ChangeNotifier {
  final DonorRepository _repository = DonorRepository();

  DonorProfile? _profile;
  List<DonorProfile> _allDonors = [];
  bool _isLoading = false;
  String? _error;

  DonorProfile? get profile => _profile;
  List<DonorProfile> get allDonors => _allDonors;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMyProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      _profile = await _repository.getMyProfile();
      _error = null;
    } catch (e) {
      _profile = null;
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createProfile({
    required String phone,
    required String bloodGroup,
    bool isAvailable = true,
    double? lastLat,
    double? lastLng,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repository.createProfile(
        phone: phone,
        bloodGroup: bloodGroup,
        isAvailable: isAvailable,
        lastLat: lastLat,
        lastLng: lastLng,
      );

      _isLoading = false;
      notifyListeners();
      return _profile != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? phone,
    String? bloodGroup,
    bool? isAvailable,
    double? lastLat,
    double? lastLng,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repository.updateMyProfile(
        phone: phone,
        bloodGroup: bloodGroup,
        isAvailable: isAvailable,
        lastLat: lastLat,
        lastLng: lastLng,
      );

      _isLoading = false;
      notifyListeners();
      return _profile != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update donor's last-known location (for distance-based matching).
  Future<DonorProfile?> updateMyLocation(double lat, double lng) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repository.updateMyLocation(lat, lng);
      _isLoading = false;
      notifyListeners();
      return _profile;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadAllDonors() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allDonors = await _repository.getAllDonors();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
