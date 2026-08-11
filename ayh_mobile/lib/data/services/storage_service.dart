import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/constants/api_constants.dart';
import '../models/user.dart';
import '../models/donor_profile.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  StorageService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await ApiConstants.loadSavedBaseUrl(getApiBaseUrl);
  }

  Future<void> saveApiBaseUrl(String url) async {
    await _prefs?.setString(ApiConstants.prefsKeyApiBaseUrl, url);
    ApiConstants.setWorkingBaseUrl(url);
  }

  Future<String?> getApiBaseUrl() async {
    return _prefs?.getString(ApiConstants.prefsKeyApiBaseUrl);
  }

  // Token management
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token');
  }

  Future<void> clearTokens() async {
    await _secureStorage.deleteAll();
  }

  // User data
  Future<void> saveUser(User user) async {
    await _prefs?.setString('user', json.encode(user.toJson()));
  }

  Future<User?> getUser() async {
    String? userJson = _prefs?.getString('user');
    if (userJson == null) return null;
    return User.fromJson(json.decode(userJson));
  }

  Future<void> clearUser() async {
    await _prefs?.remove('user');
  }

  // Donor profile
  Future<void> saveDonorProfile(DonorProfile profile) async {
    await _prefs?.setString('donor_profile', json.encode(profile.toJson()));
  }

  Future<DonorProfile?> getDonorProfile() async {
    String? profileJson = _prefs?.getString('donor_profile');
    if (profileJson == null) return null;
    return DonorProfile.fromJson(json.decode(profileJson));
  }

  Future<void> clearDonorProfile() async {
    await _prefs?.remove('donor_profile');
  }

  // Clear all data
  Future<void> clearAll() async {
    await clearTokens();
    await clearUser();
    await clearDonorProfile();
    await clearAcceptanceCount();
  }

  /// Usable local session requires both tokens (access alone is not enough to refresh).
  Future<bool> isLoggedIn() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    return access != null &&
        access.isNotEmpty &&
        refresh != null &&
        refresh.isNotEmpty;
  }

  // Legacy intro flag (old screens)
  static const String _keyIntroSeen = 'intro_seen';

  Future<bool> getIntroSeen() async {
    return _prefs?.getBool(_keyIntroSeen) ?? false;
  }

  Future<void> setIntroSeen() async {
    await _prefs?.setBool(_keyIntroSeen, true);
  }

  /// Onboarding story cards — separate from legacy intro_seen.
  static const String _keyOnboardingCompleted = 'onboarding_completed_v2';

  Future<bool> getOnboardingCompleted() async {
    return _prefs?.getBool(_keyOnboardingCompleted) ?? false;
  }

  Future<void> setOnboardingCompleted() async {
    await _prefs?.setBool(_keyOnboardingCompleted, true);
    await setIntroSeen();
  }

  // Acceptance count (bell badge - increases when donor accepts)
  static const String _keyAcceptanceCount = 'acceptance_count';

  Future<int> getAcceptanceCount() async {
    return _prefs?.getInt(_keyAcceptanceCount) ?? 0;
  }

  Future<void> setAcceptanceCount(int count) async {
    await _prefs?.setInt(_keyAcceptanceCount, count);
  }

  Future<void> incrementAcceptanceCount() async {
    final n = await getAcceptanceCount();
    await setAcceptanceCount(n + 1);
  }

  Future<void> clearAcceptanceCount() async {
    await _prefs?.remove(_keyAcceptanceCount);
  }
}
