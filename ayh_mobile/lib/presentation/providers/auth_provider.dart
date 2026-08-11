import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/api_constants.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user.dart';
import '../../data/models/donor_profile.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();

  User? _user;
  DonorProfile? _donorProfile;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  DonorProfile? get donorProfile => _donorProfile;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _user?.isStaff ?? false;
  bool get hasDonorProfile => _donorProfile != null;

  /// Completed donor = profile exists with a non-empty blood group.
  /// Empty Google-era profiles are treated as onboarding incomplete.
  bool get hasCompletedDonorProfile {
    final group = (_donorProfile?.bloodGroup ?? '').trim();
    return group.isNotEmpty;
  }

  /// Restores session only when usable JWT tokens exist AND Django validates them.
  /// Cached user JSON alone never counts as authenticated.
  Future<void> checkLoginStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final hasTokens = await _authRepository.isLoggedIn();
      if (!hasTokens) {
        // Drop any orphaned cached user left after token wipe.
        await _authRepository.clearLocalSession();
        _user = null;
        _donorProfile = null;
        _isLoggedIn = false;
      } else {
        final result = await _authRepository.getCurrentUser();
        if (result['success'] == true && result['user'] != null) {
          _user = result['user'] as User;
          _donorProfile = result['donor_profile'] as DonorProfile?;
          _isLoggedIn = true;
          await _authRepository.persistSessionUser(
            user: _user!,
            donorProfile: _donorProfile,
          );
        } else {
          // Invalid/expired/unrefreshable session → fully logged out.
          await _authRepository.clearLocalSession();
          _user = null;
          _donorProfile = null;
          _isLoggedIn = false;
        }
      }
    } catch (e) {
      await _authRepository.clearLocalSession();
      _user = null;
      _donorProfile = null;
      _isLoggedIn = false;
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authRepository.login(username, password);
      
      if (result['success']) {
        _user = result['user'];
        _donorProfile = result['donor_profile'];
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (ApiConstants.googleServerClientId.trim().isEmpty) {
        _error =
            'Google Sign-In is not configured. Pass --dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID>.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: ApiConstants.googleServerClientId.trim(),
      );

      // Force account picker so switching Google accounts works in demos.
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) {
        _error = 'Google Sign-In was cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        _error =
            'Google did not return an ID token. Check Android OAuth client + SHA-1 and serverClientId.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final result = await _authRepository.loginWithGoogleIdToken(idToken);
      if (result['success']) {
        _user = result['user'];
        _donorProfile = result['donor_profile'];
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = result['error'] ?? 'Google Sign-In failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      final raw = e.toString();
      // ApiException 10 = DEVELOPER_ERROR: Android OAuth client / SHA-1 / package mismatch.
      if (raw.contains('ApiException: 10') || raw.contains('sign_in_failed')) {
        _error =
            'Google Sign-In misconfigured (error 10). In Google Cloud Console create an '
            'Android OAuth client for package com.example.ayh_mobile with this PC\'s '
            'debug SHA-1, wait a few minutes, then fully restart the app '
            '(keep using --dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID>).';
      } else {
        _error = raw;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String? firstName,
    String? lastName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authRepository.register(
        username: username,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
        firstName: firstName,
        lastName: lastName,
      );
      
      if (result['success']) {
        _user = result['user'];
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _donorProfile = null;
    _isLoggedIn = false;
    _error = null;
    notifyListeners();
  }

  void updateDonorProfile(DonorProfile profile) {
    _donorProfile = profile;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authRepository.requestPasswordReset(email);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }
}
