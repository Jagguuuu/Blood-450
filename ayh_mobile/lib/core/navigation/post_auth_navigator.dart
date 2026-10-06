import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/donor_provider.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/donor/donor_home_screen.dart';

/// Shared post-auth routing. Donor opt-in happens at registration or via home CTA —
/// never as a blocking dialog after every login.
class PostAuthNavigator {
  PostAuthNavigator._();

  static Future<void> continueAfterAuth(
    BuildContext context, {
    /// Kept for call-site compatibility; incomplete donors always go home.
    bool declineToHome = true,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.isAdmin) {
      _go(context, const AdminDashboardScreen());
      return;
    }

    final donorProvider = Provider.of<DonorProvider>(context, listen: false);
    await donorProvider.loadMyProfile();
    if (!context.mounted) return;

    if (donorProvider.profile != null) {
      auth.updateDonorProfile(donorProvider.profile!);
    }

    // Non-donors land on home and can opt in later via the Become a Donor CTA.
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
