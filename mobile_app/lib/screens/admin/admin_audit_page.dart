import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/owner_studios_provider.dart' show OwnerActionException;
import 'admin_ui.dart';

/// Trang NHẬT KÝ: ai đã duyệt / từ chối / gỡ studio, khoá / mở khoá tài khoản, lúc nào, vì sao.
class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => AdminAuditPageState();
}

class AdminAuditPageState extends State<AdminAuditPage> {
  String? _type; // null | studio | user
  List<AuditLogRow> _rows = [];
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
      final res = await context.read<AdminProvider>().auditLogs(targetType: _type, page: _page + 1);
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

  static IconData _icon(String action) {
    if (action.contains('Phê duyệt')) return Icons.check_circle_outline_rounded;
    if (action.contains('Từ chối')) return Icons.cancel_outlined;
    if (action.contains('Gỡ')) return Icons.remove_circle_outline_rounded;
    if (action.contains('Ẩn')) return Icons.visibility_off_outlined;
    if (action.contains('Hiện lại')) return Icons.visibility_outlined;
    if (action.contains('báo cáo')) return Icons.flag_outlined;
    if (action.contains('Mở khóa')) return Icons.lock_open_rounded;
    if (action.contains('Khóa')) return Icons.lock_outline_rounded;
    return Icons.history_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Nhật ký quản trị',
      subtitle: 'Lưu lại mọi thao tác của quản trị viên',
      onRefresh: load,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (value, label) in [(null, 'Tất cả'), ('studio', 'Studio'), ('user', 'Tài khoản'), ('review', 'Đánh giá')])
              ChoiceChip(
                label: Text(label),
                selected: _type == value,
                onSelected: (_) {
                  setState(() => _type = value);
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
            child: Text('Chưa có thao tác nào.', textAlign: TextAlign.center),
          )
        else
          AdminCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: Icon(_icon(_rows[i].action), color: AppColors.textBody),
                  title: Text(
                    '${_rows[i].action}: ${_rows[i].targetName ?? '(đã xoá)'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      '${_rows[i].adminName} · ${fmtDateTime(_rows[i].createdAt)}',
                      if ((_rows[i].note ?? '').isNotEmpty) 'Lý do: ${_rows[i].note}',
                    ].join('\n'),
                  ),
                  isThreeLine: (_rows[i].note ?? '').isNotEmpty,
                ),
              ],
            ],
          ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (_rows.length < _total)
          Center(child: OutlinedButton(onPressed: _loadMore, child: const Text('Xem thêm'))),
      ],
    );
  }
}
