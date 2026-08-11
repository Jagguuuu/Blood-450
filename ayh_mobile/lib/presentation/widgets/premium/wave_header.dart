import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Asymmetric wave header — distinct from login's simple curve.
class WaveHeader extends StatelessWidget {
  final double height;
  final Widget? child;

  const WaveHeader({super.key, this.height = 280, this.child});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _AsymmetricWaveClipper(),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB71C1C),
              Color(0xFFD32F2F),
              Color(0xFFEF5350),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

class _AsymmetricWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.72);
    path.cubicTo(
      size.width * 0.85,
      size.height * 0.95,
      size.width * 0.35,
      size.height * 0.55,
      0,
      size.height * 0.88,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Soft white wave overlay for sheet transition.
class WhiteWaveSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const WhiteWaveSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _SheetWaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _SheetWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 36);
    path.quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, 8);
    path.quadraticBezierTo(size.width * 0.75, 16, size.width, 4);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
