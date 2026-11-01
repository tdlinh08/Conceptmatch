import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Tên + màu của từng trạng thái đơn — dùng chung cho danh sách và màn chi tiết.
(String, Color) bookingStatusInfo(String status) => switch (status) {
      'pending' => ('Chờ xác nhận', AppColors.statusWarning),
      'confirmed' => ('Đã xác nhận', AppColors.statusSuccess),
      'checked_in' => ('Đã đến studio', AppColors.accentText),
      'completed' => ('Hoàn thành', AppColors.textBody),
      'cancelled' => ('Đã huỷ', AppColors.textFaint),
      'rejected' => ('Bị từ chối', AppColors.statusError),
      'no_show' => ('Vắng mặt', AppColors.statusError),
      // Hai nhãn chỉ có ở app (đơn còn hiệu lực nhưng đã qua giờ):
      'expired' => ('Quá hạn', AppColors.textFaint), // studio chưa xác nhận
      'awaiting_update' => ('Chờ studio cập nhật', AppColors.statusWarning),
      _ => (status, AppColors.textBody),
    };

class BookingStatusBadge extends StatelessWidget {
  final String status;
  final bool large;

  const BookingStatusBadge({super.key, required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    final (label, color) = bookingStatusInfo(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 9, vertical: large ? 6 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(large ? 12 : 10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: large ? 13 : 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
