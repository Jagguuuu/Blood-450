import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/donor_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import 'donor_home_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  /// Pre-selected blood group when opened from post-registration donor popup.
  final String? initialBloodGroup;

  const CreateProfileScreen({super.key, this.initialBloodGroup});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  late String? _selectedBloodGroup;
  bool _isAvailable = true;
  bool _gettingLocation = false;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    _selectedBloodGroup = widget.initialBloodGroup;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Turn on location in device settings.'),
            ),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. You can enter coordinates manually below.',
              ),
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) {
        setState(() {
          _latController.text = pos.latitude.toStringAsFixed(6);
          _lngController.text = pos.longitude.toStringAsFixed(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location set'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location timed out. Enter latitude & longitude manually below (e.g. from Google Maps).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get location: $e. Enter manually below.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _handleCreate() async {
    if (_formKey.currentState!.validate()) {
      double? lastLat = double.tryParse(_latController.text.trim());
      double? lastLng = double.tryParse(_lngController.text.trim());
      if (lastLat != null && lastLng != null) {
        if (lastLat < -90 || lastLat > 90 || lastLng < -180 || lastLng > 180) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Latitude must be -90 to 90, longitude -180 to 180.',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      } else {
        lastLat = null;
        lastLng = null;
      }

      final donorProvider = Provider.of<DonorProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final success = await donorProvider.createProfile(
        phone: _phoneController.text.trim(),
        bloodGroup: _selectedBloodGroup!,
        isAvailable: _isAvailable,
        lastLat: lastLat,
        lastLng: lastLng,
      );

      if (!mounted) return;

      if (success) {
        authProvider.updateDonorProfile(donorProvider.profile!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DonorHomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(donorProvider.error ?? 'Failed to create profile'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Donor Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<DonorProvider>(
        builder: (context, donorProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Complete your profile to start receiving blood donation requests',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Phone: allow all characters (no format or length restriction)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      hintText: 'Enter phone number',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) return 'Required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedBloodGroup,
                    decoration: InputDecoration(
                      labelText: 'Blood Group *',
                      prefixIcon: const Icon(Icons.bloodtype),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _bloodGroups.map((group) {
                      return DropdownMenuItem(
                        value: group,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.getBloodGroupColor(
                                  group,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  group,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getBloodGroupColor(group),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(group),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBloodGroup = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select blood group' : null,
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Location (optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Set your location to get matched with nearby blood requests. Enter coordinates or use current location.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Latitude',
                            hintText: 'e.g. 17.4842',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Longitude',
                            hintText: 'e.g. 78.3894',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _gettingLocation ? null : _useCurrentLocation,
                    icon: _gettingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: Text(
                      _gettingLocation
                          ? 'Getting location...'
                          : 'Use current location',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Available to Donate'),
                    subtitle: const Text('Enable to receive donation requests'),
                    value: _isAvailable,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value;
                      });
                    },
                    activeThumbColor: AppColors.primary,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: donorProvider.isLoading ? null : _handleCreate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: donorProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
