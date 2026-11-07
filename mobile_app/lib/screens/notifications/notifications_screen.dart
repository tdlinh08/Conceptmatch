import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../providers/notifications_provider.dart';
import '../bookings/booking_detail_screen.dart';

/// Màn "Thông báo": mới nhất lên đầu, chưa đọc có nền hồng + chấm.
/// Bấm thông báo về đơn đặt -> đánh dấu đã đọc + mở "Chi tiết lịch hẹn".
class NotificationsScreen extends StatefulWidget {
  /// Chủ studio truyền vào để tự xử lý khi bấm thông báo (vd mở tab Lịch đặt,
  /// mở studio vừa được duyệt). Không truyền = cách của khách: mở Chi tiết lịch hẹn.
  final void Function(AppNotification n)? onOpen;

  const NotificationsScreen({super.key, this.onOpen});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().fetch();
    });
  }

  void _open(AppNotification n) {
    context.read<NotificationsProvider>().markRead(n);
    if (widget.onOpen != null) {
      widget.onOpen!(n);
      return;
    }
    if (n.opensBooking) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: n.refId!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (provider.unread > 0)
            TextButton(
              onPressed: provider.markAllRead,
              child: const Text('Đọc tất cả'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.fetch,
        child: Builder(
          builder: (context) {
            if (provider.isLoading && items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return _Empty(
                icon: provider.errorMessage != null
                    ? Icons.wifi_off_rounded
                    : Icons.notifications_none_rounded,
                text: provider.errorMessage ??
                    'Chưa có thông báo nào.\nKhi studio xác nhận lịch hoặc có cập nhật, bạn sẽ thấy ở đây.',
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _NotificationTile(
                notification: items[i],
                onTap: () => _open(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  /// Biểu tượng + màu theo loại thông báo.
  static (IconData, Color) _style(String type) => switch (type) {
        'booking_new' => (Icons.event_available_rounded, AppColors.accentText),
        'booking_confirmed' => (Icons.check_circle_outline_rounded, AppColors.statusSuccess),
        'booking_rejected' => (Icons.cancel_outlined, AppColors.statusError),
        'booking_cancelled' => (Icons.event_busy_rounded, AppColors.statusWarning),
        'booking_completed' => (Icons.photo_camera_outlined, AppColors.accentText),
        'review_new' => (Icons.star_rounded, AppColors.ratingGold),
        'studio_approved' => (Icons.verified_outlined, AppColors.statusSuccess),
        'studio_rejected' => (Icons.report_gmailerrorred_rounded, AppColors.statusError),
        _ => (Icons.notifications_none_rounded, AppColors.textBody),
      };

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, color) = _style(n.type);

    return Material(
      color: n.isRead ? AppColors.surface : AppColors.surfacePink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: n.isRead ? AppColors.outline : AppColors.dustyMauve.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w700,
                              color: AppColors.textTitle,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.accentText,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textBody),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _relativeTime(n.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Vừa xong", "5 phút trước", "3 giờ trước", "Hôm qua 14:20", "02/11 09:00"
String _relativeTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24 && DateUtils.isSameDay(now, t)) return '${diff.inHours} giờ trước';
  final yesterday = now.subtract(const Duration(days: 1));
  if (DateUtils.isSameDay(yesterday, t)) return 'Hôm qua ${two(t.hour)}:${two(t.minute)}';
  return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    // ListView để vẫn kéo xuống làm mới được khi chưa có thông báo
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(36, 96, 36, 80),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.surfacePink, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: AppColors.accentText),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
        ),
      ],
    );
  }
}
