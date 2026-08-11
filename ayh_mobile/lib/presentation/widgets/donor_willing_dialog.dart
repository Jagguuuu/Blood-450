import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Shows after registration: "Would you like to give blood?" then optionally blood group picker.
class DonorWillingDialog {
  static const List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  /// Shows only "Would you like to be a blood donor?" Yes/Not now. No phone or blood group screen.
  /// Caller should then navigate to login.
  static Future<void> showWillingOnly(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Become a Blood Donor?'),
        content: const Text(
          'Would you like to register as a blood donor? You\'ll be notified when someone needs your blood type. You can set up your profile after logging in.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Yes, I\'d like to donate'),
          ),
        ],
      ),
    );
  }

  /// Returns true if user wants to be donor and selected blood group (then caller should navigate to create profile).
  /// Returns false with null blood group if user declined.
  static Future<({bool willing, String? bloodGroup})> show(BuildContext context) async {
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Yes, I\'d like to donate'),
          ),
        ],
      ),
    );

    if (willing != true) return (willing: false, bloodGroup: null);

    String? bloodGroup = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BloodGroupPickerDialog(),
    );

    return (willing: true, bloodGroup: bloodGroup);
  }
}

class _BloodGroupPickerDialog extends StatefulWidget {
  @override
  State<_BloodGroupPickerDialog> createState() => _BloodGroupPickerDialogState();
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
              selectedColor: AppColors.getBloodGroupColor(bg).withOpacity(0.3),
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
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
