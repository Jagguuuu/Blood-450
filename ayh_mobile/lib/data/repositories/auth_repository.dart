import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';
import '../models/donor_profile.dart';

/// Auth via Django API (Vercel). Supabase is the database on the server only.
class AuthRepository {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  Future<Map<String, dynamic>> login(String username, String password) async {
    final result = await _authService.login(username, password);

    if (result['success']) {
      await _storageService.saveTokens(
        result['access'] as String,
        result['refresh'] as String,
      );
      await _storageService.saveUser(result['user'] as User);
      if (result['donor_profile'] != null) {
        await _storageService.saveDonorProfile(result['donor_profile'] as DonorProfile);
      }
    }

    return result;
  }

  Future<Map<String, dynamic>> loginWithGoogleIdToken(String idToken) async {
    final result = await _authService.loginWithGoogleIdToken(idToken);

    if (result['success']) {
      await _storageService.saveTokens(
        result['access'] as String,
        result['refresh'] as String,
      );
      await _storageService.saveUser(result['user'] as User);
      if (result['donor_profile'] != null) {
        await _storageService.saveDonorProfile(
          result['donor_profile'] as DonorProfile,
        );
      }
    }

    return result;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String? firstName,
    String? lastName,
  }) async {
    final result = await _authService.register(
      username: username,
      email: email,
      password: password,
      passwordConfirm: passwordConfirm,
      firstName: firstName,
      lastName: lastName,
    );

    if (result['success']) {
      await _storageService.saveTokens(
        result['access'] as String,
        result['refresh'] as String,
      );
      await _storageService.saveUser(result['user'] as User);
    }

    return result;
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    return _authService.requestPasswordReset(email);
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    return await _authService.getCurrentUser();
  }

  Future<void> logout() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _authService.logout(refreshToken);
      } catch (_) {
        // Always clear local auth even if server logout fails.
      }
    }
    await clearLocalSession();
  }

  /// Clears tokens + cached user/profile. Does not clear onboarding prefs.
  Future<void> clearLocalSession() async {
    await _storageService.clearAll();
  }

  Future<void> persistSessionUser({
    required User user,
    DonorProfile? donorProfile,
  }) async {
    await _storageService.saveUser(user);
    if (donorProfile != null) {
      await _storageService.saveDonorProfile(donorProfile);
    } else {
      await _storageService.clearDonorProfile();
    }
  }

  Future<User?> getCachedUser() async {
    return await _storageService.getUser();
  }

  Future<DonorProfile?> getCachedDonorProfile() async {
    return await _storageService.getDonorProfile();
  }

  Future<bool> isLoggedIn() async {
    return await _storageService.isLoggedIn();
  }
}
