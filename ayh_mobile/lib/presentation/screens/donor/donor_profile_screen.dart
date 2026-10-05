import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donor_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/location/device_location.dart';
import 'edit_donor_profile_screen.dart';

/// Screen showing donor's user and profile details.
class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({super.key});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  bool _updatingLocation = false;

  Future<void> _openEdit(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final profile = auth.donorProfile;
    if (user == null || profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a donor profile before editing.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditDonorProfileScreen(user: user, profile: profile),
      ),
    );
  }

  Future<void> _updateMyLocation() async {
    if (_updatingLocation) return;
    final donorProvider = context.read<DonorProvider>();
    final authProvider = context.read<AuthProvider>();

    setState(() => _updatingLocation = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location...'),
          duration: Duration(seconds: 2),
        ),
      );

      final coords = await DeviceLocation.getCoordinates();
      if (!mounted) return;

      final profile = await donorProvider.updateMyLocation(
        coords.latitude,
        coords.longitude,
      );

      if (!mounted) return;

      if (profile != null) {
        authProvider.updateDonorProfile(profile);
        final label = profile.readableLocation.isNotEmpty
            ? profile.readableLocation
            : 'Location detected';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location updated\n📍 $label'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              donorProvider.error ?? 'Failed to update location.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } on DeviceLocationException catch (e) {
      if (!mounted) return;
      if (e.failure == DeviceLocationFailure.serviceDisabled) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location disabled'),
            content: const Text(
              'Turn on location in device settings to update your location.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        if (openSettings == true) await Geolocator.openLocationSettings();
      } else if (e.failure == DeviceLocationFailure.permissionDeniedForever) {
        final openApp = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location permission'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        if (openApp == true) await Geolocator.openAppSettings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DeviceLocation.userMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.donorProfile == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _openEdit(context),
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;
          final profile = authProvider.donorProfile;
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      user.username.isNotEmpty
                          ? user.username.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (profile != null)
                  FilledButton.icon(
                    onPressed: () => _openEdit(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                const SizedBox(height: 20),
                _buildCard(context, 'Account', [
                  _row('Username', user.username),
                  _row('Email', user.email),
                  if (user.firstName.isNotEmpty || user.lastName.isNotEmpty)
                    _row('Name', user.displayName),
                ]),
                const SizedBox(height: 16),
                if (profile != null)
                  _buildCard(context, 'Donor Profile', [
                    _row('Blood Group', profile.bloodGroup),
                    _row('Phone', profile.phone),
                    _row(
                      'Available to donate',
                      profile.isAvailable ? 'Yes' : 'No',
                    ),
                    _row(
                      'Last donation',
                      profile.lastDonationDate != null
                          ? '${profile.lastDonationDate!.day}/${profile.lastDonationDate!.month}/${profile.lastDonationDate!.year}'
                          : 'Not set',
                    ),
                    _row(
                      'Eligibility',
                      profile.eligibilityStatus == 'eligible'
                          ? 'Eligible'
                          : profile.eligibilityStatus == 'cooling_off'
                              ? 'Cooling off'
                              : 'No info',
                    ),
                    _row(
                      'Last location',
                      profile.readableLocation.isNotEmpty
                          ? '📍 ${profile.readableLocation}'
                          : (profile.hasCoordinates
                              ? '📍 Location available'
                              : 'Location not set'),
                    ),
                    if (profile.locationUpdatedAt != null)
                      _row(
                        'Location updated',
                        _formatDate(profile.locationUpdatedAt!),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _updatingLocation ? null : _updateMyLocation,
                      icon: _updatingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(
                        _updatingLocation
                            ? 'Updating...'
                            : 'Update my location',
                      ),
                    ),
                  ])
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Donor Profile',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No donor profile yet. Create one from the app to receive blood requests.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  Widget _buildCard(BuildContext context, String title, List<Widget> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
