import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const CategoryChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(_capitalize(label)),
        onPressed: onTap,
        backgroundColor: AppColors.surfaceVariant,
        side: BorderSide.none,
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
