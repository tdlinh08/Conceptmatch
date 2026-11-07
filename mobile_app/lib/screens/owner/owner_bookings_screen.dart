import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/owner_booking_model.dart';
import '../../models/studio_detail_model.dart' show StaffRoles;
import '../../providers/owner_bookings_provider.dart';
import '../../providers/owner_studios_provider.dart';
import '../bookings/widgets/booking_status_badge.dart';
import 'owner_booking_detail_screen.dart';

/// Tab "Lịch đặt" của chủ studio: 3 tab Chờ xác nhận / Sắp tới / Đã xong,
/// lọc theo studio, bấm đơn để xem chi tiết và xử lý.
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OwnerBookingsProvider>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OwnerBookingsProvider>();
    final studios = context.watch<OwnerStudiosProvider>().studios;
    final pendingTotal = provider.list(OwnerBookingTab.pending).total;

    return DefaultTabController(
      length: OwnerBookingTab.values.length,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Lịch đặt',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ),
                    if (studios.length > 1)
                      _StudioFilter(
                        value: provider.studioId,
                        studios: [for (final s in studios) (s.id, s.name)],
                        onChanged: provider.setStudio,
                      ),
                  ],
                ),
              ),
              TabBar(
                labelColor: AppColors.textTitle,
                unselectedLabelColor: AppColors.textFaint,
                indicatorColor: AppColors.primary,
                tabs: [
                  for (final t in OwnerBookingTab.values)
                    Tab(
                      text: t == OwnerBookingTab.pending && pendingTotal > 0
                          ? '${t.label} ($pendingTotal)'
                          : t.label,
                    ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [for (final t in OwnerBookingTab.values) _BookingList(tab: t)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút chọn studio (chỉ hiện khi chủ có từ 2 studio).
class _StudioFilter extends StatelessWidget {
  final String? value;
  final List<(String, String)> studios;
  final ValueChanged<String?> onChanged;

  const _StudioFilter({required this.value, required this.studios, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    String label = 'Tất cả studio';
    for (final (id, name) in studios) {
      if (id == value) label = name;
    }
    return PopupMenuButton<String>(
      tooltip: 'Lọc theo studio',
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('Tất cả studio')),
        for (final (id, name) in studios) PopupMenuItem(value: id, child: Text(name)),
      ],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 170),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outlineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 16, color: AppColors.textBody),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textTitle),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textBody),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final OwnerBookingTab tab;

  const _BookingList({required this.tab});

  static String _emptyText(OwnerBookingTab tab) => switch (tab) {
        OwnerBookingTab.pending => 'Không có đơn nào chờ xác nhận.',
        OwnerBookingTab.upcoming => 'Chưa có lịch chụp sắp tới.',
        OwnerBookingTab.past => 'Chưa có đơn nào kết thúc.',
      };

  Future<void> _open(BuildContext context, OwnerBookingItem b) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OwnerBookingDetailScreen(bookingId: b.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OwnerBookingsProvider>();
    final l = provider.list(tab);

    Widget body;
    if (!l.loaded && l.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!l.loaded && l.error != null) {
      body = ListView(
        children: [
          const SizedBox(height: 80),
          Text(l.error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: () => provider.refresh(tab),
              child: const Text('Thử lại'),
            ),
          ),
        ],
      );
    } else if (l.items.isEmpty) {
      body = ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.event_available_outlined, size: 48, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(
            _emptyText(tab),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.textBody),
          ),
        ],
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) provider.loadMore(tab);
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: l.items.length + (l.hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= l.items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final b = l.items[i];
            // Nhóm theo ngày: hiện tiêu đề ngày khi khác ngày đơn trước
            final showDate = i == 0 || !DateUtils.isSameDay(l.items[i - 1].startTime, b.startTime);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDate)
                  Padding(
                    padding: EdgeInsets.fromLTRB(4, i == 0 ? 0 : 12, 4, 8),
                    child: Text(
                      Formatters.dateLabel(b.startTime),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                _BookingCard(booking: b, onTap: () => _open(context, b)),
              ],
            );
          },
        ),
      );
    }

    return RefreshIndicator(onRefresh: () => provider.refresh(tab), child: body);
  }
}

class _BookingCard extends StatelessWidget {
  final OwnerBookingItem booking;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final detail = [
      b.setName,
      if (b.packageName != null) b.packageName!,
      '${b.numPeople} người',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: b.status == 'pending' && !b.isOverdue ? AppColors.accentText : AppColors.outline,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${Formatters.hm(b.startTime)} – ${Formatters.hm(b.endTime)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const Spacer(),
                    BookingStatusBadge(status: b.displayStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  b.customerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                Text(
                  b.studioName,
                  style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
                if (b.addons.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in b.addons)
                        _Chip(
                          a.staffName == null
                              ? '${StaffRoles.label(a.role)}: chưa phân công'
                              : '${StaffRoles.label(a.role)}: ${a.staffName}',
                          warn: a.staffName == null && b.status == 'pending',
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if ((b.specialNote ?? '').trim().isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.textFaint),
                      ),
                    const Spacer(),
                    Text(
                      Formatters.vnd(b.totalAmount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool warn;
  const _Chip(this.text, {this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warn ? AppColors.statusWarning.withValues(alpha: 0.1) : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: warn ? AppColors.statusWarning : AppColors.textBody),
      ),
    );
  }
}
