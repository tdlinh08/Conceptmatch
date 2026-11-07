import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../../models/owner_studio_model.dart' show StudioStatus;
import '../../providers/admin_provider.dart';
import '../../providers/owner_studios_provider.dart' show OwnerActionException;
import '../owner/widgets/studio_status_badge.dart';
import 'admin_studio_detail_screen.dart';
import 'admin_ui.dart';

/// Trang STUDIO: 3 nhóm Chờ duyệt / Đang hoạt động / Bị từ chối, tìm theo tên, quận, chủ studio.
class AdminStudiosPage extends StatefulWidget {
  const AdminStudiosPage({super.key});

  @override
  State<AdminStudiosPage> createState() => AdminStudiosPageState();
}

class AdminStudiosPageState extends State<AdminStudiosPage> {
  static const _pageSize = 20;
  static const _statuses = [StudioStatus.pending, StudioStatus.active, StudioStatus.rejected];

  String _status = StudioStatus.pending;
  final _search = TextEditingController();
  Timer? _debounce;

  List<AdminStudioRow> _rows = [];
  Map<String, int> _counts = {};
  int _total = 0;
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

  /// Tải lại từ trang 1 (gọi khi đổi tab / tìm / quay lại từ chi tiết).
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
      final res = await context.read<AdminProvider>().studios(
            status: _status,
            keyword: _search.text,
            page: _page + 1,
            limit: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...res.page.items];
        _total = res.page.total;
        _counts = res.counts;
        _page++;
      });
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), load);
  }

  Future<void> _open(AdminStudioRow s) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminStudioDetailScreen(studioId: s.id)),
    );
    if (changed == true && mounted) load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Studio',
      subtitle: 'Duyệt hồ sơ studio mới, xem và gỡ studio vi phạm',
      onRefresh: load,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final s in _statuses)
                  ButtonSegment(
                    value: s,
                    label: Text('${StudioStatus.label(s)} (${_counts[s] ?? 0})'),
                  ),
              ],
              selected: {_status},
              onSelectionChanged: (v) {
                setState(() => _status = v.first);
                load();
              },
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Tên studio, quận, tên / email chủ studio',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null && _rows.isEmpty)
          Column(
            children: [
              Text(_error!),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: load, child: const Text('Thử lại')),
            ],
          )
        else if (!_loading && _rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              _status == StudioStatus.pending
                  ? 'Không có studio nào chờ duyệt.'
                  : 'Không có studio nào.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textBody),
            ),
          )
        else
          AdminCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _StudioRow(row: _rows[i], onTap: () => _open(_rows[i])),
              ],
            ],
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
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

class _StudioRow extends StatelessWidget {
  final AdminStudioRow row;
  final VoidCallback onTap;

  const _StudioRow({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = row;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: r.coverImage == null
                    ? const ColoredBox(
                        color: AppColors.surfacePink,
                        child: Icon(Icons.storefront_outlined, color: AppColors.accentText),
                      )
                    : Image.network(
                        r.coverImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(color: AppColors.surfaceMuted),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,
                    ),
                  ),
                  Text(
                    '${r.address}, ${r.district}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                  ),
                  Text(
                    'Chủ: ${r.ownerName} (${r.ownerEmail}) · gửi ${fmtDate(r.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                  if (r.status == StudioStatus.rejected && (r.rejectReason ?? '').isNotEmpty)
                    Text(
                      'Lý do: ${r.rejectReason}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.statusError),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StudioStatusBadge(status: r.status),
                const SizedBox(height: 6),
                Text(
                  '${r.setCount} bối cảnh · ${r.imageCount} ảnh',
                  style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
                if (r.status == StudioStatus.active)
                  Text(
                    '${r.bookingCount} đơn',
                    style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
