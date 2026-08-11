import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Red curved gradient header for auth screens.
class CurvedHeader extends StatelessWidget {
  final double height;
  final Widget? child;

  const CurvedHeader({super.key, this.height = 260, this.child});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedClipper(),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: child,
      ),
    );
  }
}

class _CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 48);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 24,
      size.width,
      size.height - 48,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
