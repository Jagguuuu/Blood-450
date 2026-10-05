import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_launch_gate.dart';
import '../../../data/services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/premium/gradient_button.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/login_screen.dart';
import '../donor/donor_home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  static const _pages = [
    _StoryCard(
      title: 'Donate Blood',
      description: 'Save lives through blood donation and help those in need.',
      icon: Icons.bloodtype_rounded,
      gradient: [Color(0xFFB71C1C), Color(0xFFEF5350)],
    ),
    _StoryCard(
      title: 'Find Donors',
      description: 'Search and connect with blood donors in real time.',
      icon: Icons.person_search_rounded,
      gradient: [Color(0xFFC62828), Color(0xFFE57373)],
    ),
    _StoryCard(
      title: 'Emergency Requests',
      description: 'Create urgent blood requests and get immediate support.',
      icon: Icons.emergency_rounded,
      gradient: [Color(0xFFD32F2F), Color(0xFFFF8A80)],
    ),
    _StoryCard(
      title: 'Nearby Blood Banks',
      description: 'Locate nearby blood banks and hospitals easily.',
      icon: Icons.local_hospital_rounded,
      gradient: [Color(0xFFB71C1C), Color(0xFFEF9A9A)],
    ),
    _StoryCard(
      title: 'Blood 450 Community',
      description:
          'Join a community dedicated to saving lives through blood donation.',
      icon: Icons.groups_rounded,
      gradient: [Color(0xFF8E0000), Color(0xFFD32F2F)],
    ),
  ];

  /// Unique slant + position per card (radians, offset dx/dy).
  static const _cardLayouts = [
    (angle: -0.09, dx: -6.0, dy: 14.0),
    (angle: 0.07, dx: 10.0, dy: -10.0),
    (angle: -0.05, dx: -12.0, dy: 6.0),
    (angle: 0.08, dx: 8.0, dy: -14.0),
    (angle: -0.06, dx: -4.0, dy: 8.0),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    AppLaunchGate.markOnboardingDoneForThisRun();
    await StorageService().setOnboardingCompleted();
    if (!mounted) return;

    // Onboarding completion is not authentication — validate JWT with Django.
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.checkLoginStatus();
    if (!mounted) return;

    final Widget destination = auth.isLoggedIn
        ? (auth.isAdmin
            ? const AdminDashboardScreen()
            : const DonorHomeScreen())
        : const LoginScreen();

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
      (route) => false,
    );
  }

  void _next() {
    if (_isLastPage) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    if (_currentPage <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF5F5),
              Color(0xFFFFFFFF),
              Color(0xFFFFEBEE),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    const Spacer(),
                    TextButton(
                      onPressed: _finish,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    _navArrow(
                      icon: Icons.chevron_left_rounded,
                      enabled: _currentPage > 0,
                      onTap: _previous,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ClipRect(
                          child: PageView.builder(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _pages.length,
                            onPageChanged: (i) {
                              HapticFeedback.selectionClick();
                              setState(() => _currentPage = i);
                            },
                            itemBuilder: (context, index) {
                              final layout = _cardLayouts[index];
                              return _OnboardingStoryCard(
                                key: ValueKey(index),
                                data: _pages[index],
                                angle: layout.angle * 0.55,
                                offsetX: layout.dx,
                                offsetY: layout.dy,
                                scale: 1.0,
                                opacity: 1.0,
                                isCenter: true,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    _navArrow(
                      icon: Icons.chevron_right_rounded,
                      enabled: !_isLastPage,
                      onTap: _isLastPage ? null : _next,
                    ),
                  ],
                ),
              ),
              _buildDotIndicators(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: GradientButton(
                  label: _isLastPage ? 'Get Started' : 'Next',
                  icon: _isLastPage
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: _next,
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navArrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 40,
      child: Center(
        child: Material(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                size: 28,
                color: enabled ? AppColors.primary : AppColors.divider,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 32 : 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: active ? AppColors.primaryGradient : null,
            color: active ? null : AppColors.lightRed,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _StoryCard {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  const _StoryCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

class _OnboardingStoryCard extends StatelessWidget {
  final _StoryCard data;
  final double angle;
  final double offsetX;
  final double offsetY;
  final double scale;
  final double opacity;
  final bool isCenter;

  const _OnboardingStoryCard({
    super.key,
    required this.data,
    required this.angle,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
    required this.opacity,
    required this.isCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: double.infinity,
                height: 168,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: isCenter ? 0.24 : 0.1,
                      ),
                      blurRadius: isCenter ? 24 : 12,
                      offset: Offset(6, isCenter ? 14 : 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: data.gradient,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.22),
                                border: Border.all(color: Colors.white38, width: 2),
                              ),
                              child: Icon(data.icon, size: 36, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      data.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      data.description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
