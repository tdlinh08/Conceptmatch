import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/owner_studios_provider.dart' show OwnerActionException;
import '../bookings/widgets/booking_status_badge.dart';
import 'admin_ui.dart';

/// Trang ĐƠN ĐẶT toàn sàn — CHỈ XEM (admin không sửa dữ liệu giao dịch, SRS 3.4.2).
/// Lọc trạng thái, khoảng ngày chụp, tìm theo khách / studio. Mở riêng được cho 1 khách
/// ([userId]) hoặc 1 studio ([studioId]) từ màn chi tiết.
class AdminBookingsPage extends StatefulWidget {
  final String? userId;
  final String? studioId;
  final String? title;

  const AdminBookingsPage({super.key, this.userId, this.studioId, this.title});

  /// Mở như một màn riêng (có nút quay lại).
  static Future<void> open(BuildContext context, {String? userId, String? studioId, required String title}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: AdminBookingsPage(userId: userId, studioId: studioId, title: title),
        ),
      ),
    );
  }

  @override
  State<AdminBookingsPage> createState() => AdminBookingsPageState();
}

class AdminBookingsPageState extends State<AdminBookingsPage> {
  static const _statuses = {
    'pending': 'Chờ xác nhận',
    'confirmed': 'Đã xác nhận',
    'checked_in': 'Đang chụp',
    'completed': 'Hoàn thành',
    'rejected': 'Từ chối',
    'cancelled': 'Khách huỷ',
    'no_show': 'Không đến',
  };

  final _search = TextEditingController();
  Timer? _debounce;
  String? _status;
  DateTimeRange? _range;

  List<AdminBookingRow> _rows = [];
  int _total = 0;
  double _sum = 0;
  int _page = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    _page = 0;
    _rows = [];
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<AdminProvider>().bookings(
            status: _status,
            keyword: _search.text,
            userId: widget.userId,
            studioId: widget.studioId,
            from: _range?.start,
            to: _range?.end,
            page: _page + 1,
          );
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...res.page.items];
        _total = res.page.total;
        _sum = res.totalAmount;
        _page++;
      });
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
      helpText: 'Chọn khoảng ngày chụp',
      saveText: 'Áp dụng',
    );
    if (picked == null) return;
    setState(() => _range = picked);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final standalone = widget.userId != null || widget.studioId != null;
    return AdminPage(
      title: standalone ? (widget.title ?? 'Đơn đặt') : 'Đơn đặt',
      subtitle: '$_total đơn · tổng ${Formatters.vnd(_sum)} · chỉ xem',
      onRefresh: load,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!standalone)
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), load);
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Tên / email khách, tên studio',
                  ),
                ),
              ),
            ActionChip(
              avatar: const Icon(Icons.date_range_rounded, size: 18),
              label: Text(_range == null
                  ? 'Mọi ngày chụp'
                  : '${fmtDate(_range!.start)} – ${fmtDate(_range!.end)}'),
              onPressed: _pickRange,
            ),
            if (_range != null)
              IconButton(
                tooltip: 'Bỏ lọc ngày',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  setState(() => _range = null);
                  load();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: _status == null,
              onSelected: (_) {
                setState(() => _status = null);
                load();
              },
            ),
            for (final e in _statuses.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _status == e.key,
                onSelected: (_) {
                  setState(() => _status = e.key);
                  load();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null && _rows.isEmpty)
          Column(children: [Text(_error!), OutlinedButton(onPressed: load, child: const Text('Thử lại'))])
        else if (!_loading && _rows.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text('Không có đơn nào.', textAlign: TextAlign.center),
          )
        else
          AdminCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _BookingRow(row: _rows[i], onTap: () => showBookingDetail(context, _rows[i])),
              ],
            ],
          ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (_rows.length < _total)
          Center(
            child: OutlinedButton(
              onPressed: _loadMore,
              child: Text('Xem thêm (${_total - _rows.length})'),
            ),
          ),
      ],
    );
  }
}

class _BookingRow extends StatelessWidget {
  final AdminBookingRow row;
  final VoidCallback onTap;
  const _BookingRow({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = row;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmtDate(b.start), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${Formatters.hm(b.start)} – ${Formatters.hm(b.end)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b.studioName} · ${b.setName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTitle),
                  ),
                  Text(
                    '${b.customerName} · ${b.numPeople} người${b.addons.isEmpty ? '' : ' · ${b.addons.length} dịch vụ'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BookingStatusBadge(status: b.status),
                const SizedBox(height: 4),
                Text(Formatters.vnd(b.totalAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại chi tiết 1 đơn (chỉ xem).
Future<void> showBookingDetail(BuildContext context, AdminBookingRow b) {
  Widget line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.textFaint))),
            Expanded(child: Text(v, style: const TextStyle(color: AppColors.textTitle))),
          ],
        ),
      );
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Chi tiết đơn')),
          BookingStatusBadge(status: b.status),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              line('Mã đơn', b.id.substring(0, 8).toUpperCase()),
              line('Khách', '${b.customerName}\n${b.customerEmail}'),
              line('Studio', '${b.studioName} · ${b.setName}'),
              if (b.packageName != null) line('Gói', '${b.packageName} · ${b.numPeople} người'),
              line('Lịch chụp',
                  '${Formatters.dateLabel(b.start)}\n${Formatters.hm(b.start)} – ${Formatters.hm(b.end)}'),
              for (final a in b.addons)
                line('Dịch vụ', '${a.name} · ${Formatters.vnd(a.amount)}${a.staff == null ? '' : '\nPhụ trách: ${a.staff}'}'),
              line('Tổng tiền', '${Formatters.vnd(b.totalAmount)} (cọc ${Formatters.vnd(b.depositAmount)})'),
              if ((b.specialNote ?? '').trim().isNotEmpty) line('Ghi chú', b.specialNote!.trim()),
              if ((b.cancelReason ?? '').isNotEmpty) line('Lý do', b.cancelReason!),
              line('Đặt lúc', fmtDateTime(b.createdAt)),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng'))],
    ),
  );
}
