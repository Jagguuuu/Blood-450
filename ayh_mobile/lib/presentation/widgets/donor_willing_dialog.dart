import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Opt-in dialog for becoming a blood donor (registration or home CTA).
class DonorWillingDialog {
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  static ButtonStyle get _primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
      );

  /// Soft reminder with a life-saving quote (home CTA / non-blocking opt-in).
  static Future<bool> showReminder(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Become a Blood Donor?'),
        content: const Text(
          '"A single pint can save three lives — and the person you help might one day help someone you love."\n\n'
          'Would you like to register as a blood donor? You\'ll be notified when someone nearby needs your blood type.',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: _primaryButtonStyle,
            child: const Text('Become a Donor'),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Returns true if user wants to be donor and selected blood group.
  static Future<({bool willing, String? bloodGroup})> show(
    BuildContext context,
  ) async {
    final willing = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Become a Blood Donor?'),
        content: const Text(
          'Would you like to register as a blood donor? You\'ll be notified when someone needs your blood type.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: _primaryButtonStyle,
            child: const Text('Yes, I\'d like to donate'),
          ),
        ],
      ),
    );

    if (willing != true) return (willing: false, bloodGroup: null);

    final bloodGroup = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _BloodGroupPickerDialog(),
    );

    return (willing: true, bloodGroup: bloodGroup);
  }
}

class _BloodGroupPickerDialog extends StatefulWidget {
  const _BloodGroupPickerDialog();

  @override
  State<_BloodGroupPickerDialog> createState() =>
      _BloodGroupPickerDialogState();
}

class _BloodGroupPickerDialogState extends State<_BloodGroupPickerDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select your blood group'),
      content: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DonorWillingDialog.bloodGroups.map((bg) {
            final isSelected = _selected == bg;
            return ChoiceChip(
              label: Text(bg),
              selected: isSelected,
              onSelected: (v) => setState(() => _selected = v ? bg : null),
              selectedColor:
                  AppColors.getBloodGroupColor(bg).withOpacity(0.3),
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: AppColors.getBloodGroupColor(bg),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          style: DonorWillingDialog._primaryButtonStyle,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
