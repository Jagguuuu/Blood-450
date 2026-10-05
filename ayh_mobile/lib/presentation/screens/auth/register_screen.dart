import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/location/device_location.dart';
import '../../widgets/premium/blood_logo.dart';
import '../../widgets/premium/gradient_button.dart';
import '../../widgets/premium/wave_header.dart';
import '../donor/donor_home_screen.dart';
import 'login_screen.dart';

/// Multi-step donor registration aligned with website (account → health → location → review).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  final _accountKey = GlobalKey<FormState>();
  final _healthKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedGender; // M / F / O / null
  String? _selectedBloodGroup;
  String? _donatedBefore; // yes / no
  String? _medicalConditions;
  String? _currentlyHealthy;
  bool _emergencyAvailable = true;
  bool _neverDonated = false;
  DateTime? _lastDonationDate;
  bool _isAvailable = true;
  bool _consentContact = false;
  bool _consentTerms = false;
  bool _gettingLocation = false;
  double? _lat;
  double? _lng;
  String _locationLabel = '';
  int _step = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  static const _genders = [
    ('M', 'Male', Icons.male_rounded),
    ('F', 'Female', Icons.female_rounded),
    ('O', 'Other', Icons.person_rounded),
    (null, 'Prefer not to say', Icons.more_horiz_rounded),
  ];
  static const _stepTitles = ['Account', 'Health', 'Location', 'Review'];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  double get _passwordStrength {
    final p = _passwordController.text;
    if (p.isEmpty) return 0;
    var score = 0.0;
    if (p.length >= 8) score += 0.35;
    if (p.length >= 12) score += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p)) score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(p)) score += 0.15;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p)) score += 0.15;
    return score.clamp(0.0, 1.0);
  }

  Future<void> _goNext() async {
    if (_step == 0) {
      if (!(_accountKey.currentState?.validate() ?? false)) return;
    } else if (_step == 1) {
      if (!(_healthKey.currentState?.validate() ?? false)) return;
      if (_selectedBloodGroup == null) {
        _toast('Please select your blood group');
        return;
      }
      if (_donatedBefore == null) {
        _toast('Please answer “Donated blood before?”');
        return;
      }
      if (_donatedBefore == 'no') {
        setState(() {
          _neverDonated = true;
          _lastDonationDate = null;
        });
      } else if (_donatedBefore == 'yes' &&
          !_neverDonated &&
          _lastDonationDate == null) {
        _toast(
          'Pick your last donation date, or check “I have never donated blood”',
        );
        return;
      }
    }
    HapticFeedback.selectionClick();
    setState(() => _step += 1);
    await _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goBack() async {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _step -= 1);
    await _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);
    try {
      final coords = await DeviceLocation.getCoordinates();
      if (!mounted) return;
      setState(() {
        _lat = coords.latitude;
        _lng = coords.longitude;
        _locationLabel = 'Location detected';
      });
      _toast('Location detected', success: true);
    } catch (e) {
      if (!mounted) return;
      _toast(DeviceLocation.userMessage(e));
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_consentContact || !_consentTerms) {
      _toast('Please accept contact consent and terms to continue');
      return;
    }
    if (_selectedBloodGroup == null || _phoneController.text.trim().isEmpty) {
      _toast('Phone and blood group are required');
      setState(() => _step = 1);
      _pageController.jumpToPage(1);
      return;
    }

    HapticFeedback.mediumImpact();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      passwordConfirm: _confirmPasswordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      bloodGroup: _selectedBloodGroup,
      gender: _selectedGender,
      isAvailable: _isAvailable,
      lastLat: _lat,
      lastLng: _lng,
      lastDonationDate: _neverDonated ? null : _lastDonationDate,
      donatedBefore: _yn(_donatedBefore),
      medicalConditions: _yn(_medicalConditions),
      currentlyHealthy: _yn(_currentlyHealthy),
      emergencyAvailable: _emergencyAvailable,
      consentContact: _consentContact,
      consentTerms: _consentTerms,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Blood450! You\'re ready to receive requests.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DonorHomeScreen()),
        (_) => false,
      );
    } else {
      _toast(authProvider.error ?? 'Registration failed');
    }
  }

  bool? _yn(String? v) {
    if (v == 'yes') return true;
    if (v == 'no') return false;
    return null;
  }

  void _toast(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return FadeTransition(
            opacity: _fadeIn,
            child: Stack(
              children: [
                _buildBackgroundBlobs(),
                SafeArea(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      _buildStepper(),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildAccountStep(),
                            _buildHealthStep(),
                            _buildLocationStep(),
                            _buildReviewStep(authProvider.isLoading),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary,
          ),
          const BloodLogo(size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Donor Registration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${_step + 1}/4',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: List.generate(_stepTitles.length, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 3 ? 0 : 6),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: done || active
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stepTitles[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active || done
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _sheet({required Widget child}) {
    return WhiteWaveSheet(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      child: child,
    );
  }

  Widget _buildAccountStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: _sheet(
        child: Form(
          key: _accountKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Account', Icons.account_circle_outlined),
              const SizedBox(height: 12),
              _registerField(
                controller: _usernameController,
                label: 'Username',
                hint: 'Choose a unique username',
                icon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 14),
              _registerField(
                controller: _emailController,
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboard: TextInputType.emailAddress,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Email is required';
                  if (!v!.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _sectionTitle('About You', Icons.favorite_outline_rounded),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _registerField(
                      controller: _firstNameController,
                      label: 'First name',
                      hint: 'First',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _registerField(
                      controller: _lastNameController,
                      label: 'Last name',
                      hint: 'Last',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Gender',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _genderGrid(),
              const SizedBox(height: 18),
              _sectionTitle('Security', Icons.shield_outlined),
              const SizedBox(height: 12),
              _registerField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Min. 8 characters',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.primary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Password required';
                  if (v!.length < 8) return 'At least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              _passwordStrengthBar(),
              const SizedBox(height: 14),
              _registerField(
                controller: _confirmPasswordController,
                label: 'Confirm password',
                hint: 'Re-enter password',
                icon: Icons.lock_reset_rounded,
                obscure: _obscureConfirmPassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.primary,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Confirm your password';
                  if (v != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              GradientButton(
                label: 'Next: Health →',
                icon: Icons.arrow_forward_rounded,
                onPressed: _goNext,
              ),
              const SizedBox(height: 12),
              _loginLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: _sheet(
        child: Form(
          key: _healthKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Health & donation', Icons.bloodtype_outlined),
              const SizedBox(height: 12),
              _registerField(
                controller: _phoneController,
                label: 'Mobile number',
                hint: '10-digit mobile',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
                validator: (v) {
                  final digits =
                      (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) return 'Enter a valid mobile number';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Blood group *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bloodGroups.map((bg) {
                  final selected = _selectedBloodGroup == bg;
                  return ChoiceChip(
                    label: Text(bg),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedBloodGroup = bg),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _ynRow(
                'Donated blood before?',
                _donatedBefore,
                (v) => setState(() {
                  _donatedBefore = v;
                  if (v == 'no') {
                    _neverDonated = true;
                    _lastDonationDate = null;
                  } else if (v == 'yes') {
                    _neverDonated = false;
                  }
                }),
              ),
              const SizedBox(height: 12),
              _ynRow(
                'Medical conditions?',
                _medicalConditions,
                (v) => setState(() => _medicalConditions = v),
              ),
              const SizedBox(height: 12),
              _ynRow(
                'Currently healthy?',
                _currentlyHealthy,
                (v) => setState(() => _currentlyHealthy = v),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available for emergency donation'),
                value: _emergencyAvailable,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _emergencyAvailable = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show me as available for requests'),
                value: _isAvailable,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _isAvailable = v),
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
                        ? 'Pick last donation date (optional)'
                        : '${_lastDonationDate!.day.toString().padLeft(2, '0')}/'
                            '${_lastDonationDate!.month.toString().padLeft(2, '0')}/'
                            '${_lastDonationDate!.year}',
                  ),
                ),
              const SizedBox(height: 28),
              GradientButton(
                label: 'Next: Location →',
                icon: Icons.arrow_forward_rounded,
                onPressed: _goNext,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: _sheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Location', Icons.location_on_outlined),
            const SizedBox(height: 8),
            const Text(
              'Set your location so we can match you with nearby blood requests. You can skip and add it later.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _lat != null
                    ? (_locationLabel.isNotEmpty
                        ? _locationLabel
                        : 'Coordinates captured')
                    : 'No location set yet',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _gettingLocation ? null : _useCurrentLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _gettingLocation ? 'Detecting…' : 'Use current location',
              ),
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Next: Review →',
              icon: Icons.arrow_forward_rounded,
              onPressed: _goNext,
            ),
            TextButton(
              onPressed: _goNext,
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep(bool loading) {
    String ynLabel(String? v) {
      if (v == 'yes') return 'Yes';
      if (v == 'no') return 'No';
      return '—';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: _sheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Review & confirm', Icons.checklist_rounded),
            const SizedBox(height: 12),
            _reviewRow('Username', _usernameController.text.trim()),
            _reviewRow('Email', _emailController.text.trim()),
            _reviewRow(
              'Name',
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                  .trim(),
            ),
            _reviewRow('Phone', _phoneController.text.trim()),
            _reviewRow('Blood group', _selectedBloodGroup ?? '—'),
            _reviewRow('Donated before', ynLabel(_donatedBefore)),
            _reviewRow('Emergency ready', _emergencyAvailable ? 'Yes' : 'No'),
            _reviewRow(
              'Location',
              _lat != null ? (_locationLabel.isEmpty ? 'Set' : _locationLabel) : 'Not set',
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consentContact,
              onChanged: (v) => setState(() => _consentContact = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I agree to be contacted for blood donation requests',
                style: TextStyle(fontSize: 13),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consentTerms,
              onChanged: (v) => setState(() => _consentTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I accept Terms & Privacy Policy',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Create My Account',
              icon: Icons.volunteer_activism_rounded,
              isLoading: loading,
              onPressed: loading ? null : _handleRegister,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: loading ? null : _goBack,
              child: const Text('← Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
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

  Widget _ynRow(String label, String? value, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Yes'),
              selected: value == 'yes',
              onSelected: (_) => onChanged('yes'),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: value == 'yes' ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('No'),
              selected: value == 'no',
              onSelected: (_) => onChanged('no'),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: value == 'no' ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackgroundBlobs() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 120,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: 200,
              left: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lightRed.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _genderGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _genders.map((g) {
        final selected = _selectedGender == g.$1;
        return ChoiceChip(
          avatar: Icon(g.$3, size: 16, color: selected ? Colors.white : AppColors.primary),
          label: Text(g.$2),
          selected: selected,
          onSelected: (_) => setState(() => _selectedGender = g.$1),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        );
      }).toList(),
    );
  }

  Widget _passwordStrengthBar() {
    final s = _passwordStrength;
    Color barColor = Colors.redAccent;
    var label = 'Weak';
    if (s >= 0.75) {
      barColor = Colors.green;
      label = 'Strong';
    } else if (s >= 0.45) {
      barColor = Colors.orange;
      label = 'Okay';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: s,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            color: barColor,
          ),
        ),
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Password strength: $label',
            style: TextStyle(
              fontSize: 11,
              color: barColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _loginLink() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            children: [
              TextSpan(text: 'Already a hero? '),
              TextSpan(
                text: 'Sign in',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _registerField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator ??
          (v) => v?.trim().isEmpty ?? true ? '$label is required' : null,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }
}
