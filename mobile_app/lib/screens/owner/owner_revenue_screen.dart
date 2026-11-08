import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/stats_models.dart';
import '../../providers/owner_studios_provider.dart';
import '../admin/admin_ui.dart';
import '../stats/stats_view.dart';

/// Tab "Doanh thu" của chủ studio: lượt đặt, doanh thu theo ngày / tháng, bối cảnh đặt nhiều nhất.
class OwnerRevenueScreen extends StatefulWidget {
  const OwnerRevenueScreen({super.key});

  @override
  State<OwnerRevenueScreen> createState() => OwnerRevenueScreenState();
}

class OwnerRevenueScreenState extends State<OwnerRevenueScreen> {
  String _range = '30d';
  String? _studioId; // null = mọi studio
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
      final r = await context.read<OwnerStudiosProvider>().stats(_range, studioId: _studioId);
      if (mounted) setState(() => _report = r);
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studios = context.watch<OwnerStudiosProvider>().studios;
    return Scaffold(
      body: AdminPage(
        title: 'Doanh thu',
        subtitle: 'Số liệu các studio của bạn',
        onRefresh: load,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RangeSelector(
                value: _range,
                onChanged: (v) {
                  setState(() => _range = v);
                  load();
                },
              ),
              if (studios.length > 1)
                DropdownButton<String?>(
                  value: _studioId,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Tất cả studio')),
                    for (final s in studios)
                      DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) {
                    setState(() => _studioId = v);
                    load();
                  },
                ),
              if (_loading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 16),
          if (_report != null)
            StatsView(report: _report!, isAdmin: false)
          else if (_error != null)
            Column(
              children: [
                Text(_error!, style: const TextStyle(color: AppColors.textBody)),
                OutlinedButton(onPressed: load, child: const Text('Thử lại')),
              ],
            ),
        ],
      ),
    );
  }
}
