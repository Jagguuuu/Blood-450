import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/post_auth_navigator.dart';
import '../../../data/services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/premium/blood_logo.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _loadingMessages = [
    'Initializing Blood450...',
    'Connecting donors...',
    'Preparing emergency network...',
    'Almost ready...',
  ];

  late AnimationController _logoController;
  late AnimationController _percentController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  int _percent = 0;
  String _loadingText = _loadingMessages.first;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _percentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _logoController.forward();
    _percentController.addListener(_onPercentTick);
    _percentController.forward().whenComplete(_navigateNext);
  }

  void _onPercentTick() {
    final value = (_percentController.value * 100).round().clamp(0, 100);
    if (value != _percent) {
      setState(() {
        _percent = value;
        if (value < 25) {
          _loadingText = _loadingMessages[0];
        } else if (value < 55) {
          _loadingText = _loadingMessages[1];
        } else if (value < 85) {
          _loadingText = _loadingMessages[2];
        } else {
          _loadingText = _loadingMessages[3];
        }
      });
    }
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Onboarding preference only — never treat as authentication.
    final onboardingDone = await StorageService().getOnboardingCompleted();
    if (!mounted) return;

    if (!onboardingDone) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.checkLoginStatus();
    if (!mounted) return;

    if (!auth.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      return;
    }

    // Admin / completed donor / incomplete → same rules as Google login.
    await PostAuthNavigator.continueAfterAuth(context);
  }

  @override
  void dispose() {
    _percentController.removeListener(_onPercentTick);
    _logoController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB71C1C),
              Color(0xFFD32F2F),
              Color(0xFFEF5350),
              Color(0xFFFFEBEE),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.35, 0.55, 0.82, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.22),
                          border: Border.all(color: Colors.white38, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const BloodLogo(size: 110, withShadow: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _logoFade,
                    child: const Text(
                      'Blood450',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _logoFade,
                    child: const Text(
                      'Every Drop Saves Lives',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      _loadingText,
                      key: ValueKey(_loadingText),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _percent < 70
                            ? Colors.white.withValues(alpha: 0.95)
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_percent%',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: _percent < 70
                          ? Colors.white
                          : AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 8,
                      child: LinearProgressIndicator(
                        value: _percent / 100,
                        backgroundColor: Colors.white.withValues(alpha: 0.35),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _percent < 70 ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
