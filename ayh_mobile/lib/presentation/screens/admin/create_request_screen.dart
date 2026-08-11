import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/blood_request_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/blood_request.dart' show MatchedDonor;

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _unitsController = TextEditingController(text: '1');
  final _noteController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '10');
  String? _selectedBloodGroup;
  String? _selectedUrgency;
  bool _useLocation = false;
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
  final List<Map<String, String>> _urgencies = [
    {'value': 'critical', 'label': 'Critical'},
    {'value': 'high', 'label': 'High'},
    {'value': 'medium', 'label': 'Medium'},
  ];

  @override
  void dispose() {
    _unitsController.dispose();
    _noteController.dispose();
    _locationNameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Location disabled'),
              content: const Text(
                'Location services are off. Turn them on in device settings to use current location.',
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
      if (mounted) {
        setState(() {
          _latController.text = pos.latitude.toStringAsFixed(6);
          _lngController.text = pos.longitude.toStringAsFixed(6);
          _useLocation = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated'),
            backgroundColor: AppColors.success,
          ),
        );
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
        ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    double? reqLat;
    double? reqLng;
    String? locationName;
    double? radiusKm;
    if (_useLocation) {
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      if (lat != null && lng != null) {
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
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
        reqLat = lat;
        reqLng = lng;
        locationName = _locationNameController.text.trim().isEmpty
            ? null
            : _locationNameController.text.trim();
        radiusKm =
            double.tryParse(_radiusController.text.trim()) ??
            ApiConstants.defaultRadiusKm;
      }
    }

    final provider = Provider.of<BloodRequestProvider>(context, listen: false);
    final result = await provider.createRequest(
      bloodGroup: _selectedBloodGroup!,
      unitsNeeded: int.parse(_unitsController.text),
      urgency: _selectedUrgency!,
      note: _noteController.text.trim(),
      reqLat: reqLat,
      reqLng: reqLng,
      locationName: locationName,
      radiusKm: radiusKm,
    );

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Request created successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      final matched = result['matched_donors'] as List<MatchedDonor>?;
      if (matched != null && matched.isNotEmpty) {
        await _showMatchedDonorsDialog(matched);
      }
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to create request'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showMatchedDonorsDialog(List<MatchedDonor> matched) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Matched donors (within radius)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${matched.length} donor(s) notified.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ...matched.map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        d.username,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (d.bloodGroup != null)
                        Text(
                          ' (${d.bloodGroup})',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      const Spacer(),
                      if (d.distanceKm != null)
                        Text(
                          '${d.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Blood Request'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<BloodRequestProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBloodGroup,
                    decoration: InputDecoration(
                      labelText: 'Blood Group Required *',
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
                    onChanged: (value) =>
                        setState(() => _selectedBloodGroup = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _unitsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Units Needed *',
                      prefixIcon: const Icon(Icons.water_drop),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final units = int.tryParse(value!);
                      if (units == null || units < 1 || units > 10) {
                        return 'Enter 1-10 units';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedUrgency,
                    decoration: InputDecoration(
                      labelText: 'Urgency Level *',
                      prefixIcon: const Icon(Icons.warning),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _urgencies.map((urgency) {
                      return DropdownMenuItem(
                        value: urgency['value'],
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.getUrgencyColor(
                                  urgency['value']!,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(urgency['label']!),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedUrgency = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _noteController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Additional Note (Optional)',
                      hintText: 'Add any additional information...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // --- Request location (optional) for distance-based matching ---
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Request location (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text(
                      'Notify only donors within radius',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _useLocation,
                    onChanged: (v) => setState(() => _useLocation = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_useLocation) ...[
                    TextFormField(
                      controller: _locationNameController,
                      decoration: InputDecoration(
                        labelText: 'Location name (e.g. Kondapur Hospital)',
                        prefixIcon: const Icon(Icons.place, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: _useLocation
                                ? (v) {
                                    if (v?.trim().isEmpty ?? true) {
                                      return 'Required when using location';
                                    }
                                    if (double.tryParse(v!.trim()) == null) {
                                      return 'Invalid number';
                                    }
                                    return null;
                                  }
                                : null,
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: _useLocation
                                ? (v) {
                                    if (v?.trim().isEmpty ?? true) {
                                      return 'Required when using location';
                                    }
                                    if (double.tryParse(v!.trim()) == null) {
                                      return 'Invalid number';
                                    }
                                    return null;
                                  }
                                : null,
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _radiusController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Radius (km)',
                        hintText: '5',
                        prefixIcon: const Icon(Icons.radar, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _useLocation
                          ? (v) {
                              final r = double.tryParse(v?.trim() ?? '');
                              if (r == null || r < 0.1 || r > 500) {
                                return 'Enter 0.1–500';
                              }
                              return null;
                            }
                          : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info, color: AppColors.info, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Auto-Notification',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _useLocation
                              ? 'Only compatible donors within the chosen radius (with location set) will be notified.'
                              : 'Compatible donors will be notified based on blood compatibility rules.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: provider.isLoading ? null : _handleCreate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: provider.isLoading
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
                            'Create Request',
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
