import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_models.dart';
import '../../providers/bookings_provider.dart';

/// Mở bảng đánh giá cho một đơn đã hoàn thành. Trả về true nếu đã gửi thành công.
Future<bool?> showReviewSheet(BuildContext context, BookingSummary booking) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true, // để bảng đẩy lên trên bàn phím
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ReviewSheet(booking: booking),
  );
}

class _ReviewSheet extends StatefulWidget {
  final BookingSummary booking;
  const _ReviewSheet({required this.booking});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _stars = 0;
  final _commentController = TextEditingController();
  bool _sending = false;

  static const _starLabels = ['', 'Tệ', 'Chưa tốt', 'Ổn', 'Tốt', 'Tuyệt vời'];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await context.read<BookingsProvider>().submitReview(
            bookingId: widget.booking.id,
            stars: _stars,
            comment: _commentController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on BookingException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + keyboard),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Đánh giá buổi chụp',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.booking.studioName} · ${widget.booking.setName}',
              style: const TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final value = i + 1;
                return IconButton(
                  tooltip: '$value sao',
                  iconSize: 40,
                  onPressed: _sending ? null : () => setState(() => _stars = value),
                  icon: Icon(
                    value <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: value <= _stars ? AppColors.ratingGold : AppColors.outlineStrong,
                  ),
                );
              }),
            ),
            SizedBox(
              height: 22,
              child: Text(
                _starLabels[_stars],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.statusWarning,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              enabled: !_sending,
              minLines: 3,
              maxLines: 5,
              maxLength: 500, // khớp giới hạn @MaxLength(500) ở backend
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Chia sẻ cảm nhận về không gian, ánh sáng, cách phục vụ… (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _stars == 0 || _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(_stars == 0 ? 'Chọn số sao để gửi' : 'Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
  }
}