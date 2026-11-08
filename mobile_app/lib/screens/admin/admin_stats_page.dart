import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/stats_models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/owner_studios_provider.dart' show OwnerActionException;
import '../stats/stats_view.dart';
import 'admin_ui.dart';

/// Trang THỐNG KÊ toàn sàn: biểu đồ doanh thu / đơn / người dùng mới, top 10 studio...
class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => AdminStatsPageState();
}

class AdminStatsPageState extends State<AdminStatsPage> {
  String _range = '30d';
  StatsReport? _report;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<AdminProvider>().stats(_range);
      if (mounted) setState(() => _report = r);
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Thống kê',
      subtitle: 'Doanh thu và hoạt động toàn sàn',
      onRefresh: load,
      children: [
        Row(
          children: [
            RangeSelector(
              value: _range,
              onChanged: (v) {
                setState(() => _range = v);
                load();
              },
            ),
            const SizedBox(width: 12),
            if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 16),
        if (_report != null)
          StatsView(report: _report!, isAdmin: true)
        else if (_error != null)
          Column(children: [Text(_error!), OutlinedButton(onPressed: load, child: const Text('Thử lại'))]),
      ],
    );
  }
}
