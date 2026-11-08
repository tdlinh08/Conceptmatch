import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/stats_models.dart';
import '../admin/admin_ui.dart';
import 'simple_bar_chart.dart';

/// Chọn kỳ thống kê.
class RangeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const RangeSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: '7d', label: Text('7 ngày')),
        ButtonSegment(value: '30d', label: Text('30 ngày')),
        ButtonSegment(value: '12m', label: Text('12 tháng')),
      ],
      selected: {value},
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}

/// Toàn bộ phần hiển thị báo cáo — dùng chung cho admin (toàn sàn) và chủ studio.
class StatsView extends StatefulWidget {
  final StatsReport report;
  final bool isAdmin;

  const StatsView({super.key, required this.report, required this.isAdmin});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  String _metric = 'revenue'; // revenue | bookings | users

  static const _statusLabels = {
    'pending': 'Chờ xác nhận',
    'confirmed': 'Đã xác nhận',
    'checked_in': 'Đang chụp',
    'completed': 'Hoàn thành',
    'rejected': 'Studio từ chối',
    'cancelled': 'Khách huỷ',
    'no_show': 'Khách không đến',
  };

  String get _periodText => switch (widget.report.range) {
        '7d' => '7 ngày qua',
        '12m' => '12 tháng qua',
        _ => '30 ngày qua',
      };

  /// 1.250.000 -> "1,3tr" (trục biểu đồ gọn)
  static String _short(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1).replaceAll('.', ',')} tỷ';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')}tr';
    if (v >= 1e3) return '${(v / 1e3).round()}k';
    return v.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final values = switch (_metric) {
      'bookings' => r.series.map((b) => b.bookings.toDouble()).toList(),
      'users' => r.series.map((b) => b.newUsers.toDouble()).toList(),
      _ => r.series.map((b) => b.revenue).toList(),
    };
    final format = _metric == 'revenue'
        ? (double v) => _short(v)
        : (double v) => v.round().toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          minItemWidth: 190,
          children: [
            StatCard(
              icon: Icons.payments_outlined,
              label: 'Doanh thu ($_periodText)',
              value: Formatters.vnd(r.revenue),
              hint: 'Từ ${r.completed} buổi chụp hoàn thành',
              highlight: true,
            ),
            StatCard(
              icon: Icons.receipt_long_outlined,
              label: 'Đơn đặt mới',
              value: '${r.bookings}',
              hint: 'Tỉ lệ huỷ / từ chối / không đến: ${r.lostRate.toStringAsFixed(1).replaceAll('.', ',')}%',
            ),
            StatCard(
              icon: Icons.trending_up_rounded,
              label: 'Giá trị trung bình / buổi',
              value: Formatters.vnd(r.avgOrderValue),
            ),
            if (widget.isAdmin)
              StatCard(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Tài khoản mới',
                value: '${r.newUsers ?? 0}',
              )
            else
              StatCard(
                icon: Icons.star_rounded,
                label: 'Đánh giá trung bình',
                value: (r.reviewCount ?? 0) == 0 ? '—' : r.avgRating!.toStringAsFixed(1),
                hint: '${r.reviewCount ?? 0} đánh giá',
              ),
          ],
        ),
        const SizedBox(height: 16),
        AdminCard(
          title: 'Theo ${r.range == '12m' ? 'tháng' : 'ngày'}',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
              for (final (key, label) in [
                ('revenue', 'Doanh thu'),
                ('bookings', 'Số đơn'),
                if (widget.isAdmin) ('users', 'Người dùng mới'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _metric == key,
                  onSelected: (_) => setState(() => _metric = key),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SimpleBarChart(
              values: values,
              labels: r.series.map((b) => b.label).toList(),
              format: format,
            ),
            const SizedBox(height: 8),
            Text(
              _metric == 'revenue'
                  ? 'Doanh thu = tổng tiền các đơn HOÀN THÀNH, tính theo ngày chụp. Chạm vào cột để xem số.'
                  : _metric == 'bookings'
                      ? 'Số đơn = đơn được tạo trong ngày (mọi trạng thái). Chạm vào cột để xem số.'
                      : 'Số tài khoản đăng ký mới. Chạm vào cột để xem số.',
              style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 760;
            final top = widget.isAdmin
                ? _RankCard(
                    title: 'Top 10 studio theo doanh thu',
                    rows: r.topStudios,
                    showRevenue: true,
                    countLabel: 'buổi',
                  )
                : _RankCard(
                    title: 'Bối cảnh được đặt nhiều nhất',
                    rows: r.topSets,
                    showRevenue: true,
                    countLabel: 'đơn',
                  );
            final status = _StatusCard(counts: r.statusCounts, labels: _statusLabels);
            return wide
                // 2 hộp cạnh nhau cao bằng nhau
                ? IntrinsicHeight(child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: top),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: status),
                    ],
                  ))
                : Column(children: [top, status]);
          },
        ),
        LayoutBuilder(
          builder: (context, c) {
            final concepts = _RankCard(title: 'Concept được đặt nhiều', rows: r.topConcepts, countLabel: 'đơn');
            final districts = _RankCard(title: 'Khu vực (quận)', rows: r.topDistricts, countLabel: 'đơn');
            return c.maxWidth >= 760
                // 2 hộp cạnh nhau cao bằng nhau
                ? IntrinsicHeight(child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: concepts),
                      const SizedBox(width: 16),
                      Expanded(child: districts),
                    ],
                  ))
                : Column(children: [concepts, districts]);
          },
        ),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  final String title;
  final List<RankRow> rows;
  final bool showRevenue;
  final String countLabel;

  const _RankCard({
    required this.title,
    required this.rows,
    this.showRevenue = false,
    required this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    final maxCount = rows.isEmpty ? 1 : rows.map((e) => e.bookings).reduce((a, b) => a > b ? a : b);
    return AdminCard(
      title: title,
      children: [
        if (rows.isEmpty)
          const Text('Chưa có dữ liệu trong kỳ này.', style: TextStyle(color: AppColors.textBody))
        else
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text('${i + 1}.', style: const TextStyle(color: AppColors.textFaint)),
                      ),
                      Expanded(
                        child: Text(
                          rows[i].subtitle == null || rows[i].subtitle!.isEmpty
                              ? rows[i].name
                              : '${rows[i].name} · ${rows[i].subtitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTitle),
                        ),
                      ),
                      Text(
                        showRevenue
                            ? '${Formatters.vnd(rows[i].revenue)} · ${rows[i].bookings} $countLabel'
                            : '${rows[i].bookings} $countLabel',
                        style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxCount == 0 ? 0 : rows[i].bookings / maxCount,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceMuted,
                        color: AppColors.accentText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Map<String, int> counts;
  final Map<String, String> labels;

  const _StatusCard({required this.counts, required this.labels});

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return AdminCard(
      title: 'Trạng thái đơn trong kỳ',
      children: [
        if (total == 0)
          const Text('Chưa có đơn nào.', style: TextStyle(color: AppColors.textBody))
        else
          for (final e in labels.entries)
            if ((counts[e.key] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(e.value, style: const TextStyle(color: AppColors.textBody))),
                    Text(
                      '${counts[e.key]} (${(counts[e.key]! * 100 / total).round()}%)',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTitle),
                    ),
                  ],
                ),
              ),
      ],
    );
  }
}
