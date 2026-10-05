import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/donor_provider.dart';
import '../../presentation/widgets/donor_willing_dialog.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/donor/create_profile_screen.dart';
import '../../presentation/screens/donor/donor_home_screen.dart';

/// Shared post-auth routing for Google (and session restore) so donor opt-in
/// matches password registration without duplicating DonorWillingDialog.
class PostAuthNavigator {
  PostAuthNavigator._();

  static Future<void> continueAfterAuth(
    BuildContext context, {
    /// After login/splash: declining donor opt-in still lands on home (session kept).
    /// After register: decline still sends user back to login (existing flow).
    bool declineToHome = true,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.isAdmin) {
      _go(context, const AdminDashboardScreen());
      return;
    }

    // Refresh donor profile from backend when possible (incomplete Google rows).
    final donorProvider = Provider.of<DonorProvider>(context, listen: false);
    await donorProvider.loadMyProfile();
    if (!context.mounted) return;

    if (donorProvider.profile != null) {
      auth.updateDonorProfile(donorProvider.profile!);
    }

    if (auth.hasCompletedDonorProfile) {
      _go(context, const DonorHomeScreen());
      return;
    }

    final result = await DonorWillingDialog.show(context);
    if (!context.mounted) return;

    if (result.willing && result.bloodGroup != null) {
      _go(
        context,
        CreateProfileScreen(initialBloodGroup: result.bloodGroup),
      );
      return;
    }

    // Match password-register "Not now" destination.
    _go(
      context,
      declineToHome ? const DonorHomeScreen() : const LoginScreen(),
    );
  }

  static void _go(BuildContext context, Widget page) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }
}
