import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking_models.dart';

/// Màn báo đặt lịch thành công. Đơn mới luôn ở trạng thái "Chờ xác nhận"
/// (pending) cho tới khi chủ studio duyệt.
class BookingSuccessScreen extends StatelessWidget {
  final CreatedBooking booking;
  final String studioName;
  final String setName;
  final DateTime date;
  final int startHour;
  final int endHour;

  const BookingSuccessScreen({
    super.key,
    required this.booking,
    required this.studioName,
    required this.setName,
    required this.date,
    required this.startHour,
    required this.endHour,
  });

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    final dateText =
        '${weekdays[date.weekday - 1]}, ${_two(date.day)}/${_two(date.month)}/${date.year}';
    final timeText = '${_two(startHour)}:00 – ${_two(endHour)}:00 (${endHour - startHour} giờ)';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.statusSuccess.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 40, color: AppColors.statusSuccess),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Đã gửi yêu cầu đặt lịch',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Studio sẽ xem và xác nhận lịch của bạn. Bạn có thể theo dõi trạng thái trong mục Lịch hẹn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          studioName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTitle,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.statusWarning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Chờ xác nhận',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Row(label: 'Bối cảnh', value: setName),
                  _Row(label: 'Ngày', value: dateText),
                  _Row(label: 'Giờ', value: timeText),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: AppColors.outline),
                  ),
                  _Row(label: 'Tổng tiền', value: Formatters.vnd(booking.totalAmount), strong: true),
                  _Row(label: 'Tiền cọc (30%)', value: Formatters.vnd(booking.depositAmount)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _Row({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textFaint)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: strong ? 16 : 14,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}