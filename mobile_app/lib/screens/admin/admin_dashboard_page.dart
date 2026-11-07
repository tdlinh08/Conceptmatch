import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/owner_studios_provider.dart' show OwnerActionException;
import 'admin_ui.dart';

/// Trang TỔNG QUAN: số studio, người dùng, đơn, doanh thu, top studio.
class AdminDashboardPage extends StatefulWidget {
  final VoidCallback onOpenPending; // bấm ô "Chờ duyệt" -> sang trang Studio

  const AdminDashboardPage({super.key, required this.onOpenPending});

  @override
  State<AdminDashboardPage> createState() => AdminDashboardPageState();
}

class AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminDashboard? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await context.read<AdminProvider>().dashboard();
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  static const _statusLabels = {
    'pending': 'Chờ xác nhận',
    'confirmed': 'Đã xác nhận',
    'checked_in': 'Đang chụp',
    'completed': 'Hoàn thành',
    'rejected': 'Studio từ chối',
    'cancelled': 'Khách huỷ',
    'no_show': 'Khách không đến',
  };

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: load, child: const Text('Thử lại')),
                ],
              ),
      );
    }
    final monthTotal = d.bookingsThisMonth.values.fold(0, (a, b) => a + b);

    return AdminPage(
      title: 'Tổng quan',
      subtitle: 'Số liệu toàn hệ thống · cập nhật ${fmtDateTime(DateTime.now())}',
      onRefresh: load,
      actions: [
        IconButton(tooltip: 'Tải lại', onPressed: load, icon: const Icon(Icons.refresh_rounded)),
      ],
      children: [
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            StatCard(
              icon: Icons.pending_actions_rounded,
              label: 'Studio chờ duyệt',
              value: '${d.pendingStudios}',
              hint: d.pendingStudios > 0 ? 'Bấm để xử lý' : 'Không có hồ sơ chờ',
              highlight: d.pendingStudios > 0,
              onTap: widget.onOpenPending,
            ),
            StatCard(
              icon: Icons.storefront_rounded,
              label: 'Studio đang hoạt động',
              value: '${d.activeStudios}',
            ),
            StatCard(
              icon: Icons.people_alt_outlined,
              label: 'Tài khoản',
              value: '${d.totalUsers}',
              hint: '${d.usersByRole['user'] ?? 0} khách · ${d.usersByRole['studio_owner'] ?? 0} chủ studio'
                  ' · +${d.newUsersThisMonth} tháng này',
            ),
            StatCard(
              icon: Icons.event_available_outlined,
              label: 'Đơn đặt hôm nay',
              value: '${d.bookingsToday}',
              hint: '$monthTotal đơn trong tháng',
            ),
            StatCard(
              icon: Icons.payments_outlined,
              label: 'Giá trị đơn hoàn thành tháng này',
              value: Formatters.vnd(d.revenueThisMonth),
              hint: 'Tổng tiền các buổi chụp đã hoàn thành',
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 760;
            final bookings = _BookingsByStatus(counts: d.bookingsThisMonth, labels: _statusLabels);
            final top = _TopStudios(rows: d.topStudios);
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: bookings),
                      const SizedBox(width: 16),
                      Expanded(child: top),
                    ],
                  )
                : Column(children: [bookings, top]);
          },
        ),
      ],
    );
  }
}

/// Đơn tháng này theo trạng thái — thanh ngang tỉ lệ.
class _BookingsByStatus extends StatelessWidget {
  final Map<String, int> counts;
  final Map<String, String> labels;

  const _BookingsByStatus({required this.counts, required this.labels});

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return AdminCard(
      title: 'Đơn đặt tháng này',
      trailing: Text('$total đơn', style: const TextStyle(color: AppColors.textFaint)),
      children: [
        if (total == 0)
          const Text('Chưa có đơn nào trong tháng.', style: TextStyle(color: AppColors.textBody))
        else
          for (final e in labels.entries)
            if ((counts[e.key] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(e.value, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: counts[e.key]! / total,
                          minHeight: 10,
                          backgroundColor: AppColors.surfaceMuted,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${counts[e.key]}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTitle),
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }
}

class _TopStudios extends StatelessWidget {
  final List<({String name, int bookings, double rating})> rows;

  const _TopStudios({required this.rows});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      title: 'Studio được đặt nhiều nhất',
      children: [
        if (rows.isEmpty)
          const Text('Chưa có dữ liệu.', style: TextStyle(color: AppColors.textBody))
        else
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: i == 0 ? AppColors.primary : AppColors.surfaceMuted,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? AppColors.onPrimary : AppColors.textBody,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(rows[i].name, overflow: TextOverflow.ellipsis)),
                  Text('${rows[i].bookings} đơn', style: const TextStyle(color: AppColors.textBody)),
                  const SizedBox(width: 12),
                  const Icon(Icons.star_rounded, size: 16, color: AppColors.ratingGold),
                  Text(rows[i].rating.toStringAsFixed(1)),
                ],
              ),
            ),
      ],
    );
  }
}
