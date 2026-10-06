import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/donor_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import 'donor_home_screen.dart';

/// Completes donor opt-in using phone/location already collected at registration.
/// Only asks for blood group, last donation, and availability.
class CreateProfileScreen extends StatefulWidget {
  /// Pre-selected blood group when opened from an opt-in flow.
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
  bool _neverDonated = false;
  DateTime? _lastDonationDate;
  bool _bootstrapping = true;
  String? _existingPhone;
  double? _existingLat;
  double? _existingLng;
  bool _needsPhone = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final donorProvider = Provider.of<DonorProvider>(context, listen: false);

    await donorProvider.loadMyProfile();
    if (!mounted) return;

    final profile = donorProvider.profile ?? auth.donorProfile;
    final phone = (profile?.phone ?? '').trim();
    setState(() {
      _existingPhone = phone;
      _needsPhone = phone.isEmpty;
      if (phone.isNotEmpty) _phoneController.text = phone;
      _existingLat = profile?.lastLat;
      _existingLng = profile?.lastLng;
      if (_selectedBloodGroup == null || _selectedBloodGroup!.isEmpty) {
        final existingBg = (profile?.bloodGroup ?? '').trim();
        if (existingBg.isNotEmpty) _selectedBloodGroup = existingBg;
      }
      if (profile?.isAvailable != null) {
        _isAvailable = profile!.isAvailable;
      }
      if (profile?.lastDonationDate != null) {
        _lastDonationDate = profile!.lastDonationDate;
      }
      _bootstrapping = false;
    });
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _needsPhone
        ? _phoneController.text.trim()
        : (_existingPhone ?? '').trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number is required to become a donor.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final donorProvider = Provider.of<DonorProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await donorProvider.createProfile(
      phone: phone,
      bloodGroup: _selectedBloodGroup!,
      isAvailable: _isAvailable,
      lastLat: _existingLat,
      lastLng: _existingLng,
      lastDonationDate: _neverDonated ? null : _lastDonationDate,
    );

    if (!mounted) return;

    if (success) {
      final saved = donorProvider.profile!;
      authProvider.updateDonorProfile(saved);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You\'re now registered as a blood donor. Thank you!'),
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
        title: const Text('Become a Donor'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _bootstrapping
          ? const Center(child: CircularProgressIndicator())
          : Consumer<DonorProvider>(
              builder: (context, donorProvider, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Phone and location from your registration will be reused. '
                          'Just confirm your blood group to start receiving requests.',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!_needsPhone && (_existingPhone ?? '').isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.phone, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Phone on file: $_existingPhone',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_needsPhone) ...[
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number *',
                              hintText: 'Enter phone number',
                              prefixIcon: const Icon(Icons.phone),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              final digits =
                                  (value ?? '').replaceAll(RegExp(r'\D'), '');
                              if (digits.length < 10) {
                                return 'Enter a valid mobile number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
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
                        SwitchListTile(
                          title: const Text('Available to Donate'),
                          subtitle:
                              const Text('Enable to receive donation requests'),
                          value: _isAvailable,
                          onChanged: (value) {
                            setState(() => _isAvailable = value);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed:
                              donorProvider.isLoading ? null : _handleCreate,
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
                                  'Become a Donor',
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
