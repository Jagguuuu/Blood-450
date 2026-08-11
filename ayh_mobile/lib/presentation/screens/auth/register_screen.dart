import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/donor_willing_dialog.dart';
import '../../widgets/premium/blood_logo.dart';
import '../../widgets/premium/gradient_button.dart';
import '../../widgets/premium/wave_header.dart';
import '../donor/create_profile_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedGender;
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  static const _genders = [
    ('Male', Icons.male_rounded),
    ('Female', Icons.female_rounded),
    ('Other', Icons.person_rounded),
    ('Prefer not to say', Icons.more_horiz_rounded),
  ];

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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
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

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      passwordConfirm: _confirmPasswordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Blood450!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      final result = await DonorWillingDialog.show(context);
      if (!mounted) return;
      if (result.willing && result.bloodGroup != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CreateProfileScreen(initialBloodGroup: result.bloodGroup),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Registration failed'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeroHeader(context)),
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset: const Offset(0, -20),
                        child: WhiteWaveSheet(
                          padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTrustBanner(),
                                const SizedBox(height: 24),
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
                                const SizedBox(height: 24),
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
                                const SizedBox(height: 18),
                                const Text(
                                  'Gender',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _genderGrid(),
                                const SizedBox(height: 24),
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
                                const SizedBox(height: 16),
                                _bloodGroupNote(),
                                const SizedBox(height: 28),
                                GradientButton(
                                  label: 'Create My Account',
                                  icon: Icons.volunteer_activism_rounded,
                                  isLoading: authProvider.isLoading,
                                  onPressed: _handleRegister,
                                ),
                                const SizedBox(height: 16),
                                _loginLink(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
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

  Widget _buildHeroHeader(BuildContext context) {
    return WaveHeader(
      height: 300,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          child: Column(
            children: [
              Row(
                children: [
                  _glassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bloodtype, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Donor signup',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const BloodLogo(size: 80, withShadow: false),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Join Blood450',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Register once. Save lives forever.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildTrustBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lightRed.withValues(alpha: 0.5),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightRed),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your data is secure. One donation can save up to 3 lives.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.4),
                  AppColors.divider.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _genderGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _genders.map((g) {
            final selected = _selectedGender == g.$1;
            return SizedBox(
              width: itemWidth,
              child: Material(
                color: selected ? AppColors.primary : Colors.white,
                elevation: selected ? 4 : 0,
                shadowColor: AppColors.primary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedGender = g.$1);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.divider,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          g.$2,
                          size: 20,
                          color: selected ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            g.$1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _passwordStrengthBar() {
    final strength = _passwordStrength;
    Color barColor;
    String label;
    if (strength < 0.35) {
      barColor = AppColors.error;
      label = 'Weak';
    } else if (strength < 0.7) {
      barColor = AppColors.warning;
      label = 'Fair';
    } else {
      barColor = AppColors.success;
      label = 'Strong';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: strength > 0 ? strength : null,
            minHeight: 5,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Password strength: $label',
            style: TextStyle(fontSize: 11, color: barColor, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _bloodGroupNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.water_drop_rounded, color: AppColors.primary, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'After signup you can pick your blood group and become available for emergency requests.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginLink() {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pop(context),
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
      validator: validator ?? (v) => v?.trim().isEmpty ?? true ? '$label is required' : null,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}
