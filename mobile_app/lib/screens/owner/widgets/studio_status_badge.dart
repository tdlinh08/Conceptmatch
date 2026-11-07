import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/owner_studio_model.dart';

/// Nhãn trạng thái duyệt: Chờ duyệt (vàng) · Đang hoạt động (xanh) · Bị từ chối (đỏ).
class StudioStatusBadge extends StatelessWidget {
  final String status;

  const StudioStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color fg, IconData icon) = switch (status) {
      StudioStatus.active => (AppColors.statusSuccess, Icons.check_circle_rounded),
      StudioStatus.rejected => (AppColors.statusError, Icons.cancel_rounded),
      _ => (AppColors.statusWarning, Icons.schedule_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            StudioStatus.label(status),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}
