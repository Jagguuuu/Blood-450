import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donor_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user.dart';
import '../../../data/models/donor_profile.dart';

/// Edit donor profile — saves directly to Django DB via PATCH /api/donors/update_me/.
class EditDonorProfileScreen extends StatefulWidget {
  final User user;
  final DonorProfile profile;

  const EditDonorProfileScreen({
    super.key,
    required this.user,
    required this.profile,
  });

  @override
  State<EditDonorProfileScreen> createState() => _EditDonorProfileScreenState();
}

class _EditDonorProfileScreenState extends State<EditDonorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;

  String? _bloodGroup;
  bool _isAvailable = true;
  bool _neverDonated = false;
  DateTime? _lastDonationDate;
  bool _saving = false;

  static const _bloodGroups = [
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
    final user = widget.user;
    final profile = widget.profile;
    _firstNameController = TextEditingController(text: user.firstName);
    _lastNameController = TextEditingController(text: user.lastName);
    _phoneController = TextEditingController(text: profile.phone);
    _bloodGroup =
        profile.bloodGroup.trim().isEmpty ? null : profile.bloodGroup;
    _isAvailable = profile.isAvailable;
    _lastDonationDate = profile.lastDonationDate;
    _neverDonated = _lastDonationDate == null;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_bloodGroup == null) {
      _toast('Please select blood group');
      return;
    }
    if (!_neverDonated && _lastDonationDate == null) {
      _toast('Pick last donation date, or check “I have never donated”');
      return;
    }

    setState(() => _saving = true);
    final donorProvider = context.read<DonorProvider>();
    final authProvider = context.read<AuthProvider>();

    final ok = await donorProvider.updateProfile(
      phone: _phoneController.text.trim(),
      bloodGroup: _bloodGroup,
      isAvailable: _isAvailable,
      lastDonationDate: _neverDonated ? null : _lastDonationDate,
      clearLastDonationDate: _neverDonated,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      donatedBefore: !_neverDonated,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok || donorProvider.profile == null) {
      _toast(donorProvider.error ?? 'Failed to save profile');
      return;
    }

    final updatedProfile = donorProvider.profile!;
    final fromApi = updatedProfile.user;
    final sessionUser = User(
      id: widget.user.id,
      username: widget.user.username,
      email: widget.user.email,
      firstName: fromApi?.firstName.isNotEmpty == true
          ? fromApi!.firstName
          : _firstNameController.text.trim(),
      lastName: fromApi?.lastName.isNotEmpty == true
          ? fromApi!.lastName
          : _lastNameController.text.trim(),
      isStaff: widget.user.isStaff,
    );

    await authProvider.applyEditedSession(
      user: sessionUser,
      profile: updatedProfile,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Changes are saved directly to your Blood450 account.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _firstNameController,
                decoration: _decoration('First name', Icons.person_outline),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastNameController,
                decoration: _decoration('Last name', Icons.person_outline),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _decoration('Phone', Icons.phone_outlined),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _bloodGroup,
                decoration: _decoration('Blood group', Icons.bloodtype),
                items: _bloodGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _bloodGroup = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available for donation requests'),
                value: _isAvailable,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
              const Divider(height: 28),
              const Text(
                'Last blood donation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Used for 90-day eligibility. Accepting a request is not a donation.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I have never donated blood'),
                value: _neverDonated,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) {
                  setState(() {
                    _neverDonated = v ?? false;
                    if (_neverDonated) _lastDonationDate = null;
                  });
                },
              ),
              if (!_neverDonated)
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
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
