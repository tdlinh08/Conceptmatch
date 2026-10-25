import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking_models.dart';
import '../../providers/bookings_provider.dart';
import '../studios/studio_detail_screen.dart';
import 'review_sheet.dart';

/// Tab "Lịch hẹn": các đơn của người dùng, chia 3 nhóm Sắp tới / Đã qua / Đã huỷ.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

enum _Tab { upcoming, finished, cancelled }

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  _Tab _tab = _Tab.upcoming;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BookingsProvider>();
      if (!provider.hasLoadedMine) provider.fetchMyBookings();
    });
  }

  List<BookingSummary> _filter(List<BookingSummary> all, _Tab tab) {
    final list = all.where((b) {
      switch (tab) {
        case _Tab.upcoming:
          return b.isUpcoming;
        case _Tab.finished:
          return b.isFinished;
        case _Tab.cancelled:
          return b.isCancelled;
      }
    }).toList();
    // Sắp tới: gần nhất lên đầu. Hai tab còn lại: mới nhất lên đầu.
    list.sort((a, b) => tab == _Tab.upcoming
        ? a.startTime.compareTo(b.startTime)
        : b.startTime.compareTo(a.startTime));
    return list;
  }

  Future<void> _confirmCancel(BookingSummary booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Huỷ lịch này?'),
        content: Text(
          'Lịch tại ${booking.studioName} lúc ${_timeRange(booking)}, ${_dateLabel(booking.startTime)} sẽ bị huỷ. '
          'Bạn không thể hoàn tác.',
          style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Giữ lịch'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.statusError),
            child: const Text('Huỷ lịch'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<BookingsProvider>().cancelBooking(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã huỷ lịch')),
      );
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      // Trạng thái trên server có thể đã đổi (vd: studio vừa xác nhận) -> tải lại.
      context.read<BookingsProvider>().fetchMyBookings();
    }
  }

  Future<void> _openReview(BookingSummary booking) async {
    final sent = await showReviewSheet(context, booking);
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!')),
      );
    }
  }

  void _openStudio(BookingSummary booking) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudioDetailScreen(studioId: booking.studioId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingsProvider>();
    final all = provider.myBookings;
    final items = _filter(all, _tab);
    final bottomInset = MediaQuery.paddingOf(context).bottom; // chừa chỗ thanh điều hướng nổi

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: provider.fetchMyBookings,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'Lịch hẹn',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: AppColors.textTitle,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      _TabPill(
                        label: 'Sắp tới',
                        count: _filter(all, _Tab.upcoming).length,
                        selected: _tab == _Tab.upcoming,
                        onTap: () => setState(() => _tab = _Tab.upcoming),
                      ),
                      const SizedBox(width: 8),
                      _TabPill(
                        label: 'Đã qua',
                        count: _filter(all, _Tab.finished).length,
                        selected: _tab == _Tab.finished,
                        onTap: () => setState(() => _tab = _Tab.finished),
                      ),
                      const SizedBox(width: 8),
                      _TabPill(
                        label: 'Đã huỷ',
                        count: _filter(all, _Tab.cancelled).length,
                        selected: _tab == _Tab.cancelled,
                        onTap: () => setState(() => _tab = _Tab.cancelled),
                      ),
                    ],
                  ),
                ),
              ),
              if (provider.isLoadingMine && all.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.mineError != null && all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(
                    icon: Icons.wifi_off_rounded,
                    text: provider.mineError!,
                    actionLabel: 'Thử lại',
                    onAction: provider.fetchMyBookings,
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(icon: Icons.event_available_outlined, text: _emptyText(_tab)),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 24),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final b = items[i];
                      return _BookingCard(
                        booking: b,
                        onTap: () => _openStudio(b),
                        onCancel: b.canCancel ? () => _confirmCancel(b) : null,
                        onReview: b.canReview ? () => _openReview(b) : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _emptyText(_Tab tab) {
    switch (tab) {
      case _Tab.upcoming:
        return 'Bạn chưa có lịch hẹn nào sắp tới.\nKhám phá studio và đặt lịch chụp nhé.';
      case _Tab.finished:
        return 'Chưa có buổi chụp nào đã hoàn thành.';
      case _Tab.cancelled:
        return 'Không có lịch nào bị huỷ.';
    }
  }
}

// =============================================================================
// Định dạng ngày giờ
// =============================================================================

String _two(int n) => n.toString().padLeft(2, '0');

String _timeRange(BookingSummary b) =>
    '${_two(b.startTime.hour)}:${_two(b.startTime.minute)} – ${_two(b.endTime.hour)}:${_two(b.endTime.minute)}';

String _dateLabel(DateTime d) {
  const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
  return '${weekdays[d.weekday - 1]}, ${_two(d.day)}/${_two(d.month)}/${d.year}';
}

// =============================================================================
// Widget con
// =============================================================================

class _TabPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count lịch',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : const BorderSide(color: AppColors.outlineStrong),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              count > 0 ? '$label · $count' : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.onPrimary : AppColors.textBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingSummary booking;
  final VoidCallback onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onReview;

  const _BookingCard({
    required this.booking,
    required this.onTap,
    this.onCancel,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final hours = b.endTime.difference(b.startTime).inMinutes / 60;
    final hoursText = hours == hours.roundToDouble() ? '${hours.round()} giờ' : '$hours giờ';

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumb(url: b.coverImage),
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
                                b.studioName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: AppColors.textTitle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(status: b.status),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.setName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                        ),
                        const SizedBox(height: 8),
                        _IconLine(icon: Icons.calendar_today_outlined, text: _dateLabel(b.startTime)),
                        const SizedBox(height: 4),
                        _IconLine(
                          icon: Icons.schedule_rounded,
                          text: '${_timeRange(b)} · $hoursText',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.outline),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.vnd(b.totalAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTitle,
                          ),
                        ),
                        Text(
                          'Cọc ${Formatters.vnd(b.depositAmount)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                        ),
                      ],
                    ),
                  ),
                  if (onCancel != null)
                    OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        foregroundColor: AppColors.statusError,
                        side: BorderSide(color: AppColors.statusError.withValues(alpha: 0.4)),
                      ),
                      child: const Text('Huỷ lịch'),
                    ),
                  if (onReview != null)
                    FilledButton.icon(
                      onPressed: onReview,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: const Icon(Icons.star_rounded, size: 18),
                      label: const Text('Đánh giá'),
                    ),
                  if (b.status == 'completed' && b.hasReview)
                    const _IconLine(
                      icon: Icons.check_circle_outline_rounded,
                      text: 'Đã đánh giá',
                      color: AppColors.statusSuccess,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    const placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE6CFD9), Color(0xFF8E7590)],
        ),
      ),
      child: Center(
        child: Icon(Icons.photo_camera_outlined, size: 22, color: Color(0xB3FFFFFF)),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        height: 72,
        child: url == null || url!.isEmpty
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _IconLine({required this.icon, required this.text, this.color = AppColors.textBody});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color == AppColors.textBody ? AppColors.textFaint : color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      'pending' => ('Chờ xác nhận', AppColors.statusWarning),
      'confirmed' => ('Đã xác nhận', AppColors.statusSuccess),
      'checked_in' => ('Đã check-in', AppColors.accentText),
      'completed' => ('Hoàn thành', AppColors.textBody),
      'cancelled' => ('Đã huỷ', AppColors.textFaint),
      'rejected' => ('Bị từ chối', AppColors.statusError),
      'no_show' => ('Vắng mặt', AppColors.statusError),
      _ => (status, AppColors.textBody),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({required this.icon, required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 140),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}