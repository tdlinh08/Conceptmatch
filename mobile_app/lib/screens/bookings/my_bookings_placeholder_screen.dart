import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Placeholder TẠM THỜI — sẽ thay bằng danh sách booking thật ở Giai đoạn 5
/// của lộ trình (sau khi có màn hình Đặt lịch ở Giai đoạn 4).
class MyBookingsPlaceholderScreen extends StatelessWidget {
  const MyBookingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lịch của tôi')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 56, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              'Chức năng đang được xây dựng',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
