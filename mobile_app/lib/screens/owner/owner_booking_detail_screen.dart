import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking_models.dart';
import '../../models/owner_booking_model.dart';
import '../../models/studio_detail_model.dart' show StaffRoles;
import '../../providers/owner_bookings_provider.dart';
import '../../providers/owner_studios_provider.dart';
import '../bookings/widgets/booking_status_badge.dart';
import 'widgets/owner_ui.dart';
import '../report/report_sheet.dart';

/// Chi tiết 1 đơn phía chủ studio + các nút xử lý theo trạng thái:
/// Chờ xác nhận -> Xác nhận (chọn thợ nếu có dịch vụ) / Từ chối (kèm lý do);
/// Đã xác nhận -> Khách đã đến / Khách không đến; Đang chụp -> Hoàn thành.
class OwnerBookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const OwnerBookingDetailScreen({super.key, required this.bookingId});

  @override
  State<OwnerBookingDetailScreen> createState() => _OwnerBookingDetailScreenState();
}

class _OwnerBookingDetailScreenState extends State<OwnerBookingDetailScreen> {
  BookingDetail? _b;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final b = await context.read<OwnerBookingsProvider>().fetchDetail(widget.bookingId);
      if (mounted) setState(() => _b = b);
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool get _startPassed => !_b!.startTime.isAfter(DateTime.now());

  /// Gửi đổi trạng thái, báo kết quả, tải lại chi tiết + số đơn chờ.
  Future<void> _update(String status, String success,
      {String? reason, Map<String, String>? assignments}) async {
    setState(() => _busy = true);
    final provider = context.read<OwnerBookingsProvider>();
    final studios = context.read<OwnerStudiosProvider>();
    try {
      await provider.updateStatus(widget.bookingId, status, reason: reason, assignments: assignments);
      studios.fetchMine(); // cập nhật số "đơn chờ" trên thanh dưới
      await _load();
      if (mounted) showToast(context, success);
    } on OwnerActionException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final b = _b!;
    Map<String, String>? assignments;
    if (b.addons.isNotEmpty) {
      setState(() => _busy = true);
      List<AvailableStaffLine> lines;
      try {
        lines = await context.read<OwnerBookingsProvider>().availableStaff(b.id);
      } on OwnerActionException catch (e) {
        if (mounted) {
          setState(() => _busy = false);
          showToast(context, e.message);
        }
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
      assignments = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _AssignSheet(lines: lines),
      );
      if (assignments == null) return; // huỷ
    } else {
      final ok = await confirmAction(
        context,
        title: 'Xác nhận đơn?',
        message: 'Khách ${b.customerName ?? ''} sẽ nhận thông báo lịch đã được xác nhận.',
        confirmLabel: 'Xác nhận',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    await _update('confirmed', 'Đã xác nhận đơn', assignments: assignments);
  }

  Future<void> _reject() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _RejectSheet(overdue: _startPassed),
    );
    if (reason == null || !mounted) return;
    await _update('rejected', 'Đã từ chối đơn', reason: reason);
  }

  Future<void> _checkIn() async {
    if (!_startPassed) {
      final ok = await confirmAction(
        context,
        title: 'Khách đến sớm?',
        message: 'Chưa tới giờ hẹn (${Formatters.hm(_b!.startTime)}). Vẫn ghi nhận khách đã đến?',
        confirmLabel: 'Ghi nhận',
      );
      if (!ok || !mounted) return;
    }
    await _update('checked_in', 'Đã ghi nhận khách đến');
  }

  Future<void> _noShow() async {
    final ok = await confirmAction(
      context,
      title: 'Khách không đến?',
      message: 'Đơn sẽ kết thúc với trạng thái "Khách không đến". Không hoàn tác được.',
      confirmLabel: 'Xác nhận',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _update('no_show', 'Đã ghi nhận khách không đến');
  }

  Future<void> _complete() async {
    final ok = await confirmAction(
      context,
      title: 'Hoàn thành buổi chụp?',
      message: 'Khách sẽ nhận thông báo mời đánh giá studio.',
      confirmLabel: 'Hoàn thành',
    );
    if (!ok || !mounted) return;
    await _update('completed', 'Đã hoàn thành buổi chụp');
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    return Scaffold(
      appBar: AppBar(title: Text(b == null ? 'Chi tiết đơn' : 'Đơn #${b.shortCode}')),
      body: Stack(
        children: [
          if (b == null)
            LoadState(error: _error, onRetry: _load)
          else
            RefreshIndicator(onRefresh: _load, child: _buildBody(b)),
          if (_busy) const BusyOverlay(),
        ],
      ),
      bottomNavigationBar: b == null ? null : _buildActions(b),
    );
  }

  Widget _buildBody(BookingDetail b) {
    final overduePending = b.status == 'pending' && _startPassed;
    final overdueActive =
        (b.status == 'confirmed' || b.status == 'checked_in') && b.endTime.isBefore(DateTime.now());
    final shown = overduePending ? 'expired' : (overdueActive ? 'awaiting_update' : b.status);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            BookingStatusBadge(status: shown, large: true),
            const Spacer(),
            Text(
              'Đặt lúc ${Formatters.hm(b.createdAt)} ${b.createdAt.day}/${b.createdAt.month}',
              style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
          ],
        ),
        if (overduePending) ...[
          const SizedBox(height: 12),
          const HintBox(
            'Đơn đã quá giờ bắt đầu mà chưa được xác nhận — chỉ có thể từ chối để khách biết.',
            warning: true,
          ),
        ],
        if (overdueActive) ...[
          const SizedBox(height: 12),
          HintBox(
            b.status == 'confirmed'
                ? 'Đã qua giờ kết thúc. Cập nhật "Khách đã đến" hoặc "Khách không đến".'
                : 'Đã qua giờ kết thúc. Bấm "Hoàn thành" để khách đánh giá được.',
            warning: true,
          ),
        ],
        if ((b.cancelReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          HintBox('Lý do: ${b.cancelReason}', warning: true),
        ],
        const SizedBox(height: 20),
        _Section(
          title: 'Khách hàng',
          children: [
            _Row(Icons.person_outline_rounded, b.customerName ?? 'Khách'),
            if ((b.customerEmail ?? '').isNotEmpty) _Row(Icons.mail_outline_rounded, b.customerEmail!),
            if ((b.specialNote ?? '').trim().isNotEmpty)
              _Row(Icons.sticky_note_2_outlined, 'Ghi chú: ${b.specialNote!.trim()}'),
          ],
        ),
        _Section(
          title: 'Lịch chụp',
          children: [
            _Row(Icons.calendar_today_outlined, Formatters.dateLabel(b.startTime)),
            _Row(
              Icons.schedule_rounded,
              '${Formatters.hm(b.startTime)} – ${Formatters.hm(b.endTime)}'
              ' (${Formatters.duration(b.endTime.difference(b.startTime).inMinutes)})',
            ),
            _Row(Icons.storefront_outlined, b.studioName),
            _Row(
              Icons.chair_outlined,
              [b.setName, if (b.packageName != null) b.packageName!, '${b.numPeople} người'].join(' · '),
            ),
          ],
        ),
        if (b.addons.isNotEmpty)
          _Section(
            title: 'Dịch vụ thêm',
            children: [
              for (final a in b.addons)
                _Row(
                  a.role == StaffRoles.makeup ? Icons.brush_outlined : Icons.photo_camera_outlined,
                  a.staffName == null
                      ? '${a.name} — chưa phân công'
                      : '${a.name} — ${a.staffName}${(a.staffPhone ?? '').isEmpty ? '' : ' (${a.staffPhone})'}',
                ),
            ],
          ),
        _Section(
          title: 'Thanh toán',
          children: [
            if (b.baseAmount != null) _Money('Giá gói', b.baseAmount!),
            if ((b.extraPeopleAmount ?? 0) > 0) _Money('Phụ thu người thêm', b.extraPeopleAmount!),
            if ((b.surchargeAmount ?? 0) > 0) _Money('Phụ thu giờ tối / cuối tuần', b.surchargeAmount!),
            for (final a in b.addons) _Money(a.name, a.amount),
            const Divider(height: 20),
            _Money('Tổng', b.totalAmount, bold: true),
            _Money('Đặt cọc (30%)', b.depositAmount),
          ],
        ),
        if (b.hasReview)
          _Section(
            title: 'Đánh giá của khách',
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < b.reviewStars! ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 20,
                    color: AppColors.ratingGold,
                  ),
                ),
              ),
              if ((b.reviewComment ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  b.reviewComment!.trim(),
                  style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
                ),
              ],
              if (b.reviewHidden)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Đánh giá này đã bị quản trị viên ẩn (không hiện công khai, không tính điểm).',
                    style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                )
              else if (b.reviewId != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showReportSheet(context, targetType: 'review', targetId: b.reviewId!),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textFaint),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Báo cáo đánh giá không đúng sự thật'),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// Nút xử lý ở đáy màn theo trạng thái đơn.
  Widget? _buildActions(BookingDetail b) {
    final List<Widget> buttons;
    switch (b.status) {
      case 'pending':
        buttons = _startPassed
            ? [Expanded(child: FilledButton(onPressed: _busy ? null : _reject, child: const Text('Từ chối đơn')))]
            : [
                Expanded(
                  child: OutlinedButton(onPressed: _busy ? null : _reject, child: const Text('Từ chối')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(onPressed: _busy ? null : _confirm, child: const Text('Xác nhận')),
                ),
              ];
      case 'confirmed':
        buttons = [
          if (_startPassed) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _noShow,
                child: const Text('Khách không đến'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(onPressed: _busy ? null : _checkIn, child: const Text('Khách đã đến')),
          ),
        ];
      case 'checked_in':
        buttons = [
          Expanded(
            child: FilledButton(onPressed: _busy ? null : _complete, child: const Text('Hoàn thành buổi chụp')),
          ),
        ];
      default:
        return null; // đơn đã kết thúc: không còn thao tác
    }
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(children: buttons),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textTitle),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Row(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textBody)),
          ),
        ],
      ),
    );
  }
}

class _Money extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  const _Money(this.label, this.amount, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? AppColors.textTitle : AppColors.textBody,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(Formatters.vnd(amount), style: style),
        ],
      ),
    );
  }
}

/// Bảng chọn người phụ trách cho từng dịch vụ của đơn. Trả về {role: staffId}.
class _AssignSheet extends StatefulWidget {
  final List<AvailableStaffLine> lines;
  const _AssignSheet({required this.lines});

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final Map<String, String> _picked = {};

  @override
  void initState() {
    super.initState();
    for (final l in widget.lines) {
      if (l.staff.isNotEmpty) _picked[l.role] = l.staff.first.id; // chọn sẵn người đầu tiên
    }
  }

  bool get _complete => widget.lines.every((l) => _picked.containsKey(l.role));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Phân công người phụ trách',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textTitle),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chỉ hiện người đang làm và rảnh trọn khung giờ của đơn.',
                style: TextStyle(fontSize: 13, color: AppColors.textFaint),
              ),
              for (final l in widget.lines) ...[
                const SizedBox(height: 16),
                Text(
                  '${l.name} (${StaffRoles.label(l.role).toLowerCase()})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textTitle),
                ),
                if (l.staff.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: HintBox(
                      'Không còn ai rảnh giờ này. Thêm người ở mục Nhân sự hoặc từ chối đơn.',
                      warning: true,
                    ),
                  )
                else
                  RadioGroup<String>(
                    groupValue: _picked[l.role],
                    onChanged: (v) => setState(() => _picked[l.role] = v!),
                    child: Column(
                      children: [
                        for (final s in l.staff)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: s.id,
                            title: Text(s.fullName),
                            subtitle: (s.phone ?? '').isEmpty ? null : Text(s.phone!),
                          ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _complete ? () => Navigator.of(context).pop(Map.of(_picked)) : null,
                child: const Text('Xác nhận đơn'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng nhập lý do từ chối (bắt buộc). Trả về lý do.
class _RejectSheet extends StatefulWidget {
  final bool overdue;
  const _RejectSheet({required this.overdue});

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  static const _quick = [
    'Studio đã kín lịch giờ này',
    'Studio có việc đột xuất / bảo trì',
    'Không đủ thợ cho dịch vụ đã chọn',
    'Quá hạn xác nhận',
  ];
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.overdue ? 'Quá hạn xác nhận' : '');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + keyboard),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Từ chối đơn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textTitle),
            ),
            const SizedBox(height: 4),
            const Text(
              'Khách sẽ nhận thông báo kèm lý do.',
              style: TextStyle(fontSize: 13, color: AppColors.textFaint),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in _quick)
                  ActionChip(label: Text(q), onPressed: () => setState(() => _c.text = q)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Lý do *'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.statusError),
              onPressed: _c.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_c.text.trim()),
              child: const Text('Từ chối đơn'),
            ),
          ],
        ),
      ),
    );
  }
}
