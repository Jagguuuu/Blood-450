import 'package:flutter/material.dart';

class AppColors {
  // Premium Red & White palette
  static const Color primary = Color(0xFFD32F2F);
  static const Color primaryDark = Color(0xFFB71C1C);
  static const Color primaryLight = Color(0xFFEF5350);
  static const Color lightRed = Color(0xFFFFCDD2);

  static const Color background = Color(0xFFFFFFFF);
  static const Color softWhite = Color(0xFFFAFAFA);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFD32F2F),
      Color(0xFFEF5350),
      Color(0xFFFFEBEE),
      Color(0xFFFFFFFF),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  // Legacy aliases
  static const Color accent = Color(0xFFD32F2F);
  static const Color accentLight = Color(0xFFEF5350);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  static const Color bloodAPositive = Color(0xFFD32F2F);
  static const Color bloodANegative = Color(0xFFE57373);
  static const Color bloodBPositive = Color(0xFF1976D2);
  static const Color bloodBNegative = Color(0xFF64B5F6);
  static const Color bloodOPositive = Color(0xFF388E3C);
  static const Color bloodONegative = Color(0xFF81C784);
  static const Color bloodABPositive = Color(0xFF7B1FA2);
  static const Color bloodABNegative = Color(0xFFBA68C8);

  static const Color urgencyCritical = Color(0xFFB71C1C);
  static const Color urgencyHigh = Color(0xFFF57C00);
  static const Color urgencyMedium = Color(0xFF1976D2);

  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFEEEEEE);

  static Color getBloodGroupColor(String bloodGroup) {
    switch (bloodGroup) {
      case 'A+':
        return bloodAPositive;
      case 'A-':
        return bloodANegative;
      case 'B+':
        return bloodBPositive;
      case 'B-':
        return bloodBNegative;
      case 'O+':
        return bloodOPositive;
      case 'O-':
        return bloodONegative;
      case 'AB+':
        return bloodABPositive;
      case 'AB-':
        return bloodABNegative;
      default:
        return primary;
    }
  }

  static Color getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return urgencyCritical;
      case 'high':
        return urgencyHigh;
      case 'medium':
        return urgencyMedium;
      default:
        return info;
    }
  }
}
