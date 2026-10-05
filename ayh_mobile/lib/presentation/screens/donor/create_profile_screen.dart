import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/donor_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/location/device_location.dart';
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
  late String? _selectedBloodGroup;
  bool _isAvailable = true;
  bool _gettingLocation = false;
  bool _neverDonated = false;
  DateTime? _lastDonationDate;

  /// Internal matching coords — never shown as editable fields.
  double? _lat;
  double? _lng;
  String _locationLabel = '';

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
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);

    try {
      final coords = await DeviceLocation.getCoordinates();
      if (!mounted) return;

      // Capture GPS first; reverse geocode happens on Django save.
      setState(() {
        _lat = coords.latitude;
        _lng = coords.longitude;
        _locationLabel = 'Location detected';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Location detected'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DeviceLocation.userMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final donorProvider = Provider.of<DonorProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await donorProvider.createProfile(
      phone: _phoneController.text.trim(),
      bloodGroup: _selectedBloodGroup!,
      isAvailable: _isAvailable,
      lastLat: _lat,
      lastLng: _lng,
      lastDonationDate: _neverDonated ? null : _lastDonationDate,
    );

    if (!mounted) return;

    if (success) {
      final saved = donorProvider.profile!;
      authProvider.updateDonorProfile(saved);
      if (saved.readableLocation.isNotEmpty) {
        setState(() => _locationLabel = saved.readableLocation);
      }

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
                        child: Text(group),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedBloodGroup = value);
                    },
                    validator: (value) =>
                        value == null ? 'Please select blood group' : null,
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const Text(
                    'Last blood donation date (optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Used only for 90-day eligibility. Accepting a request is not a donation.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I have never donated blood'),
                    value: _neverDonated,
                    onChanged: (v) {
                      setState(() {
                        _neverDonated = v ?? false;
                        if (_neverDonated) _lastDonationDate = null;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (!_neverDonated) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _lastDonationDate ?? now,
                          firstDate: DateTime(now.year - 40),
                          lastDate: now,
                          helpText: 'Last blood donation date',
                        );
                        if (picked != null && mounted) {
                          setState(() => _lastDonationDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _lastDonationDate == null
                            ? 'Pick last donation date'
                            : '${_lastDonationDate!.day.toString().padLeft(2, '0')}/'
                                '${_lastDonationDate!.month.toString().padLeft(2, '0')}/'
                                '${_lastDonationDate!.year}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(),
                  const Row(
                    children: [
                      Icon(Icons.location_on, size: 20, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
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
                    'Set your location to get matched with nearby blood requests.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _lat != null
                          ? '📍 ${_locationLabel.isNotEmpty ? _locationLabel : 'Location detected'}'
                          : '📍 Location unavailable',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
                          : (_lat != null
                              ? 'Try again'
                              : 'Use current location'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Available to Donate'),
                    subtitle: const Text('Enable to receive donation requests'),
                    value: _isAvailable,
                    onChanged: (value) {
                      setState(() => _isAvailable = value);
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
