import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking_models.dart';
import '../../providers/bookings_provider.dart';
import '../studios/studio_detail_screen.dart';
import 'review_sheet.dart';
import 'widgets/booking_status_badge.dart';

/// Màn "Chi tiết lịch hẹn": trạng thái, lịch chụp, dịch vụ + thợ phụ trách,
/// chi tiết thanh toán, liên hệ studio và các thao tác theo trạng thái
/// (huỷ khi đang chờ, đánh giá khi đã hoàn thành).
class BookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  BookingDetail? _detail;
  String? _error;
  bool _busy = false; // đang huỷ

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final detail = await context.read<BookingsProvider>().fetchBookingDetail(widget.bookingId);
      if (mounted) setState(() => _detail = detail);
    } on BookingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Bản tóm tắt trong danh sách (cần cho bảng đánh giá + cập nhật danh sách sau khi huỷ).
  BookingSummary? _summary(BookingsProvider provider) {
    for (final b in provider.myBookings) {
      if (b.id == widget.bookingId) return b;
    }
    return null;
  }

  Future<void> _confirmCancel(BookingDetail d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Huỷ lịch này?'),
        content: Text(
          'Lịch tại ${d.studioName} lúc ${_timeRange(d.startTime, d.endTime)}, ${_dateLabel(d.startTime)} sẽ bị huỷ. '
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

    setState(() => _busy = true);
    final provider = context.read<BookingsProvider>();
    try {
      await provider.cancelBooking(d.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã huỷ lịch')));
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      provider.fetchMyBookings(); // studio có thể vừa xác nhận -> đồng bộ lại danh sách
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _load();
  }

  Future<void> _openReview(BookingSummary summary) async {
    final sent = await showReviewSheet(context, summary);
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!')),
      );
      _load();
    }
  }

  void _openStudio(BookingDetail d) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudioDetailScreen(studioId: d.studioId)),
    );
  }

  Future<void> _copyPhone(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép số $phone')),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingsProvider>();
    final summary = _summary(provider);
    final d = _detail;

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết lịch hẹn')),
      body: d == null
          ? (_error == null
              ? const Center(child: CircularProgressIndicator())
              : _ErrorView(message: _error!, onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _buildHeader(d),
                  const SizedBox(height: 16),
                  _StatusSection(detail: d),
                  const SizedBox(height: 16),
                  _Card(
                    title: 'Lịch chụp',
                    children: [
                      _Row(label: 'Ngày', value: _dateLabel(d.startTime)),
                      _Row(
                        label: 'Giờ',
                        value: '${_timeRange(d.startTime, d.endTime)} '
                            '(${Formatters.duration(d.endTime.difference(d.startTime).inMinutes)})',
                      ),
                      _Row(label: 'Bối cảnh', value: d.setName),
                      if (d.packageName != null) _Row(label: 'Gói', value: d.packageName!),
                      _Row(label: 'Số người', value: '${d.numPeople} người'),
                    ],
                  ),
                  if (d.addons.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Card(
                      title: 'Dịch vụ thêm',
                      children: [for (final a in d.addons) _AddonTile(line: a, status: d.status)],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildPayment(d),
                  if (d.specialNote != null && d.specialNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Card(
                      title: 'Ghi chú của bạn',
                      children: [
                        Text(
                          d.specialNote!.trim(),
                          style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
                        ),
                      ],
                    ),
                  ],
                  if (d.hasReview) ...[
                    const SizedBox(height: 12),
                    _Card(
                      title: 'Đánh giá của bạn',
                      children: [
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= d.reviewStars! ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 20,
                                color: AppColors.ratingGold,
                              ),
                          ],
                        ),
                        if (d.reviewComment != null && d.reviewComment!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            d.reviewComment!.trim(),
                            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Mã đơn #${d.shortCode} · Đặt lúc ${_two(d.createdAt.hour)}:${_two(d.createdAt.minute)} '
                    '${_two(d.createdAt.day)}/${_two(d.createdAt.month)}/${d.createdAt.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: d == null ? null : _buildActions(d, summary),
    );
  }

  Widget _buildHeader(BookingDetail d) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 72,
                height: 72,
                child: d.coverImage == null
                    ? const _ThumbPlaceholder()
                    : Image.network(
                        d.coverImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const _ThumbPlaceholder(),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.studioName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fullAddress(d),
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _copyPhone(d.studioPhone),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.call_outlined, size: 15, color: AppColors.accentText),
                          const SizedBox(width: 6),
                          Text(
                            d.studioPhone,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 14, color: AppColors.textFaint),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayment(BookingDetail d) {
    final extra = d.extraPeopleAmount ?? 0;
    final surcharge = d.surchargeAmount ?? 0;
    final hasBreakdown = d.baseAmount != null;

    return _Card(
      title: 'Thanh toán',
      children: [
        if (hasBreakdown) ...[
          _Row(label: 'Giá gói', value: Formatters.vnd(d.baseAmount!)),
          if (extra > 0) _Row(label: 'Người thêm', value: '+${Formatters.vnd(extra)}'),
          if (surcharge > 0) _Row(label: 'Phụ thu giờ', value: '+${Formatters.vnd(surcharge)}'),
          for (final a in d.addons) _Row(label: a.name, value: '+${Formatters.vnd(a.amount)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.outline),
          ),
        ],
        _Row(label: 'Tổng tiền', value: Formatters.vnd(d.totalAmount), strong: true),
        _Row(label: 'Tiền cọc (30%)', value: Formatters.vnd(d.depositAmount)),
        _Row(label: 'Còn lại', value: Formatters.vnd(d.totalAmount - d.depositAmount)),
        const SizedBox(height: 6),
        const Text(
          'Phần còn lại thanh toán trực tiếp tại studio.',
          style: TextStyle(fontSize: 12, color: AppColors.textFaint),
        ),
      ],
    );
  }

  /// Thanh thao tác dưới cùng, đổi theo trạng thái đơn.
  Widget? _buildActions(BookingDetail d, BookingSummary? summary) {
    final canCancel = d.status == 'pending';
    final canReview = d.status == 'completed' && !d.hasReview && summary != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openStudio(d),
                  child: const Text('Xem studio'),
                ),
              ),
              if (canCancel) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _confirmCancel(d),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusError,
                      side: BorderSide(color: AppColors.statusError.withValues(alpha: 0.4)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Huỷ lịch'),
                  ),
                ),
              ],
              if (canReview) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _openReview(summary!), // canReview đã kiểm tra khác null
                    child: const Text('Đánh giá'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fullAddress(BookingDetail d) {
    final address = d.studioAddress.trim();
    if (address.toLowerCase().contains(d.studioDistrict.trim().toLowerCase())) return address;
    return '$address, ${d.studioDistrict}';
  }
}

// =============================================================================
// Định dạng
// =============================================================================

String _two(int n) => n.toString().padLeft(2, '0');

String _timeRange(DateTime start, DateTime end) =>
    '${_two(start.hour)}:${_two(start.minute)} – ${_two(end.hour)}:${_two(end.minute)}';

String _dateLabel(DateTime d) {
  const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
  return '${weekdays[d.weekday - 1]}, ${_two(d.day)}/${_two(d.month)}/${d.year}';
}

// =============================================================================
// Widget con
// =============================================================================

/// Trạng thái đơn: tiến trình 4 bước khi đơn đang đi đúng luồng;
/// hộp màu kèm lý do khi đơn bị từ chối / huỷ / vắng mặt.
class _StatusSection extends StatelessWidget {
  final BookingDetail detail;

  const _StatusSection({required this.detail});

  static const _steps = ['pending', 'confirmed', 'checked_in', 'completed'];
  static const _labels = ['Chờ xác nhận', 'Đã xác nhận', 'Đến studio', 'Hoàn thành'];

  @override
  Widget build(BuildContext context) {
    final status = detail.status;
    final (label, color) = bookingStatusInfo(status);

    if (!_steps.contains(status)) {
      final message = switch (status) {
        'rejected' => 'Studio đã từ chối lịch này.',
        'cancelled' => 'Bạn đã huỷ lịch này.',
        'no_show' => 'Studio ghi nhận bạn không đến buổi chụp.',
        _ => label,
      };
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookingStatusBadge(status: status, large: true),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 14, color: AppColors.textTitle)),
            if (detail.cancelReason != null && detail.cancelReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Lý do: ${detail.cancelReason!.trim()}',
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textBody),
              ),
            ],
          ],
        ),
      );
    }

    final current = _steps.indexOf(status);
    final hint = switch (status) {
      'pending' => 'Studio đang xem yêu cầu của bạn. Bạn vẫn có thể huỷ khi lịch chưa được xác nhận.',
      'confirmed' => 'Lịch đã được giữ. Hãy đến đúng giờ và mang theo mã đơn.',
      'checked_in' => 'Bạn đã đến studio. Chúc buổi chụp vui vẻ!',
      _ => 'Buổi chụp đã hoàn thành. Cảm ơn bạn đã sử dụng ConceptMatch.',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                Expanded(child: _StepDot(label: _labels[i], done: i <= current, current: i == current)),
                if (i < _steps.length - 1)
                  Container(
                    width: 14,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 22),
                    color: i < current ? AppColors.primary : AppColors.outlineStrong,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(hint, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textBody)),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool current;

  const _StepDot({required this.label, required this.done, required this.current});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.primary : AppColors.surface,
            border: Border.all(color: done ? AppColors.primary : AppColors.outlineStrong, width: 2),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: AppColors.onPrimary)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            color: done ? AppColors.textTitle : AppColors.textFaint,
          ),
        ),
      ],
    );
  }
}

/// Một dịch vụ thêm: tên + tiền + thợ phụ trách (hoặc "chờ phân công").
class _AddonTile extends StatelessWidget {
  final BookingAddonLine line;
  final String status;

  const _AddonTile({required this.line, required this.status});

  @override
  Widget build(BuildContext context) {
    final isMakeup = line.role == 'makeup';
    final String staffText;
    if (line.staffName != null) {
      staffText = '${isMakeup ? 'Thợ trang điểm' : 'Thợ ảnh'}: ${line.staffName}';
    } else if (status == 'pending') {
      staffText = 'Studio sẽ phân công khi xác nhận lịch';
    } else {
      staffText = 'Chưa phân công';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.surfacePink, shape: BoxShape.circle),
            child: Icon(
              isMakeup ? Icons.brush_outlined : Icons.photo_camera_outlined,
              size: 18,
              color: AppColors.accentText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  staffText,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: line.staffName != null ? FontWeight.w600 : FontWeight.w400,
                    color: line.staffName != null ? AppColors.accentText : AppColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Formatters.vnd(line.amount),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textTitle),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
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

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFEAD7DF), Color(0xFFA48AA3)],
        ),
      ),
      child: Center(
        child: Icon(Icons.photo_camera_outlined, size: 22, color: Color(0xB3FFFFFF)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
