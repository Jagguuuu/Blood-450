import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donor_provider.dart';
import '../../../core/constants/app_colors.dart';

/// Screen showing donor's user and profile details.
class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({super.key});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  bool _updatingLocation = false;

  Future<void> _updateMyLocation() async {
    if (_updatingLocation) return;
    final donorProvider = context.read<DonorProvider>();
    final authProvider = context.read<AuthProvider>();

    setState(() => _updatingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
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
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          final openApp = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Location permission'),
              content: const Text(
                'Location access was permanently denied. Open app settings to allow location?',
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
          if (openApp == true) await Geolocator.openAppSettings();
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required. Allow it when prompted.',
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Getting your location...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final profile = await donorProvider.updateMyLocation(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) {
        if (profile != null) {
          authProvider.updateDonorProfile(profile);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location updated. You\'ll be matched for nearby requests.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update location.')),
          );
        }
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on location in device settings.')),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location timed out. Ensure GPS/location is on and try again.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                    backgroundColor: AppColors.primary.withOpacity(0.2),
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
                const SizedBox(height: 24),
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
                    if (profile.lastLat != null && profile.lastLng != null) ...[
                      _row(
                        'Last location',
                        '${profile.lastLat!.toStringAsFixed(4)}, ${profile.lastLng!.toStringAsFixed(4)}',
                      ),
                      if (profile.locationUpdatedAt != null)
                        _row(
                          'Location updated',
                          _formatDate(profile.locationUpdatedAt!),
                        ),
                    ] else
                      _row('Last location', 'Not set (tap below to update)'),
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
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}
