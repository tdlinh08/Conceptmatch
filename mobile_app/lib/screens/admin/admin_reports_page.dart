import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/owner_studios_provider.dart' show OwnerActionException;
import 'admin_studio_detail_screen.dart';
import 'admin_ui.dart';

/// Trang BÁO CÁO VI PHẠM: hàng chờ xử lý (cũ nhất lên đầu) và lịch sử đã xử lý.
/// Đánh giá -> Ẩn đánh giá / Bỏ qua. Studio -> Xem hồ sơ / Gỡ studio / Bỏ qua.
class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => AdminReportsPageState();
}

class AdminReportsPageState extends State<AdminReportsPage> {
  String _status = 'pending';
  List<ReportRow> _rows = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    load();
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
      final res = await context.read<AdminProvider>().reports(status: _status, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...res.items];
        _total = res.total;
        _page++;
      });
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _act(Future<void> Function(AdminProvider p) action, String success) async {
    final p = context.read<AdminProvider>();
    try {
      await action(p);
      if (mounted) _toast(success);
      load();
    } on OwnerActionException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _hideReview(ReportRow r) async {
    final note = await askReason(
      context,
      title: 'Ẩn đánh giá này?',
      hint: 'Đánh giá sẽ không hiện công khai và không tính vào điểm studio',
      confirmLabel: 'Ẩn đánh giá',
      quick: const ['Ngôn từ xúc phạm', 'Nội dung sai sự thật', 'Spam / quảng cáo'],
    );
    if (note == null) return;
    await _act((p) => p.resolveReport(r.id, 'hide_review', note), 'Đã ẩn đánh giá');
  }

  Future<void> _takeDown(ReportRow r) async {
    final note = await askReason(
      context,
      title: 'Gỡ studio "${r.studioName}"?',
      hint: 'Khách sẽ không thấy studio; chủ studio nhận thông báo kèm lý do',
      confirmLabel: 'Gỡ studio',
      quick: const ['Thông tin sai sự thật', 'Nhiều phản ánh từ khách hàng', 'Studio ngừng hoạt động'],
    );
    if (note == null) return;
    await _act((p) => p.resolveReport(r.id, 'take_down', note), 'Đã gỡ studio');
  }

  Future<void> _dismiss(ReportRow r) async {
    final c = TextEditingController(text: 'Không phát hiện vi phạm');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ qua báo cáo?'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: c,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Ghi chú gửi người báo cáo'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Bỏ qua')),
        ],
      ),
    );
    final note = c.text.trim();
    c.dispose();
    if (ok != true) return;
    await _act((p) => p.dismissReport(r.id, note), 'Đã bỏ qua báo cáo');
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Báo cáo vi phạm',
      subtitle: 'Khách hàng và chủ studio báo cáo studio / đánh giá không phù hợp',
      onRefresh: load,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 'pending',
              label: Text('Chờ xử lý (${context.watch<AdminProvider>().pendingReports})'),
            ),
            const ButtonSegment(value: 'resolved', label: Text('Đã xử lý')),
            const ButtonSegment(value: 'dismissed', label: Text('Đã bỏ qua')),
          ],
          selected: {_status},
          onSelectionChanged: (v) {
            setState(() => _status = v.first);
            load();
          },
        ),
        const SizedBox(height: 16),
        if (_error != null && _rows.isEmpty)
          Column(children: [Text(_error!), OutlinedButton(onPressed: load, child: const Text('Thử lại'))])
        else if (!_loading && _rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              _status == 'pending' ? 'Không có báo cáo nào chờ xử lý.' : 'Chưa có báo cáo nào.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textBody),
            ),
          )
        else
          for (final r in _rows) _ReportCard(
            report: r,
            onHide: () => _hideReview(r),
            onTakeDown: () => _takeDown(r),
            onDismiss: () => _dismiss(r),
            onOpenStudio: r.isStudio
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AdminStudioDetailScreen(studioId: r.targetId)),
                    )
                : null,
          ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (_rows.length < _total)
          Center(child: OutlinedButton(onPressed: _loadMore, child: const Text('Xem thêm'))),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportRow report;
  final VoidCallback onHide;
  final VoidCallback onTakeDown;
  final VoidCallback onDismiss;
  final VoidCallback? onOpenStudio;

  const _ReportCard({
    required this.report,
    required this.onHide,
    required this.onTakeDown,
    required this.onDismiss,
    this.onOpenStudio,
  });

  @override
  Widget build(BuildContext context) {
    final r = report;
    final pending = r.status == 'pending';
    return AdminCard(
      children: [
        Row(
          children: [
            Icon(r.isStudio ? Icons.storefront_outlined : Icons.rate_review_outlined,
                color: AppColors.accentText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                r.isStudio ? 'Studio: ${r.studioName ?? '(không còn)'}' : 'Đánh giá về ${r.reviewStudioName ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textTitle),
              ),
            ),
            if (r.reportsOnTarget > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.statusError.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Bị báo cáo ${r.reportsOnTarget} lần',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.statusError),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!r.isStudio && r.reviewStars != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${'★' * r.reviewStars!}${'☆' * (5 - r.reviewStars!)}  ${r.reviewAuthor ?? ''}'
              '${r.reviewHidden ? ' · ĐÃ ẨN' : ''}\n${(r.reviewComment ?? '').trim().isEmpty ? '(không có nội dung)' : r.reviewComment!.trim()}',
              style: const TextStyle(height: 1.5, color: AppColors.textBody),
            ),
          ),
        const SizedBox(height: 8),
        Text('Lý do: ${r.reason}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTitle)),
        if ((r.detail ?? '').isNotEmpty)
          Text(r.detail!, style: const TextStyle(color: AppColors.textBody)),
        const SizedBox(height: 4),
        Text(
          'Người báo cáo: ${r.reporterName} (${AdminUserRow.roleLabel(r.reporterRole)}, ${r.reporterEmail}) · '
          '${fmtDateTime(r.createdAt)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
        ),
        if (!pending) ...[
          const SizedBox(height: 6),
          Text(
            '${r.status == 'resolved' ? 'Đã xử lý' : 'Đã bỏ qua'} bởi ${r.handledBy ?? ''}'
            '${r.handledAt == null ? '' : ' · ${fmtDateTime(r.handledAt!)}'} — ${r.adminNote ?? ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.statusSuccess),
          ),
        ],
        if (pending) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (onOpenStudio != null)
                OutlinedButton(onPressed: onOpenStudio, child: const Text('Xem hồ sơ studio')),
              TextButton(onPressed: onDismiss, child: const Text('Bỏ qua')),
              if (r.isStudio && r.studioStatus == 'active')
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.statusError),
                  onPressed: onTakeDown,
                  child: const Text('Gỡ studio'),
                ),
              if (!r.isStudio)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.statusError),
                  onPressed: onHide,
                  child: const Text('Ẩn đánh giá'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
