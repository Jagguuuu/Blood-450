import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class BloodLogo extends StatelessWidget {
  final double size;
  final bool withShadow;

  const BloodLogo({super.key, this.size = 120, this.withShadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: withShadow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/blood450_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.lightRed,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bloodtype_rounded, size: size * 0.45, color: AppColors.primary),
                Text(
                  '450',
                  style: TextStyle(
                    fontSize: size * 0.18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
