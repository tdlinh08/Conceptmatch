import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/owner_studios_provider.dart' show OwnerActionException;
import '../bookings/widgets/booking_status_badge.dart';
import '../owner/widgets/studio_status_badge.dart';
import 'admin_bookings_page.dart';
import 'admin_studio_detail_screen.dart';
import 'admin_ui.dart';

/// Hồ sơ 1 tài khoản: thông tin, số liệu đặt lịch, đơn gần đây, đánh giá đã viết,
/// studio sở hữu (chủ studio), lịch sử khoá / mở khoá; khoá / mở khoá ngay tại đây.
class AdminUserDetailScreen extends StatefulWidget {
  final String userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  AdminUserDetail? _d;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<AdminProvider>().user(widget.userId);
      if (mounted) setState(() => _d = d);
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggleLock() async {
    final u = _d!.user;
    final provider = context.read<AdminProvider>();
    try {
      if (u.isLocked) {
        await provider.unlockUser(u.id);
        if (!mounted) return;
        _toast('Đã mở khoá tài khoản');
      } else {
        final reason = await askReason(
          context,
          title: 'Khoá tài khoản ${u.fullName}?',
          hint: 'Người dùng sẽ bị đăng xuất và không đăng nhập được',
          confirmLabel: 'Khoá',
          quick: const ['Đặt lịch ảo nhiều lần', 'Đánh giá sai sự thật', 'Vi phạm điều khoản sử dụng'],
        );
        if (reason == null) return;
        await provider.lockUser(u.id, reason);
        if (!mounted) return;
        _toast('Đã khoá tài khoản');
      }
      _changed = true;
      await _load();
    } on OwnerActionException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  static const _statusLabels = {
    'pending': 'Chờ xác nhận',
    'confirmed': 'Đã xác nhận',
    'checked_in': 'Đang chụp',
    'completed': 'Hoàn thành',
    'rejected': 'Studio từ chối',
    'cancelled': 'Tự huỷ',
    'no_show': 'Không đến',
  };

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(d?.user.fullName ?? 'Tài khoản'),
          actions: [
            if (d != null && d.user.role != 'admin')
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: d.user.isLocked
                    ? OutlinedButton(onPressed: _toggleLock, child: const Text('Mở khoá'))
                    : TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppColors.statusError),
                        onPressed: _toggleLock,
                        child: const Text('Khoá tài khoản'),
                      ),
              ),
          ],
        ),
        body: d == null
            ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
            : _body(d),
      ),
    );
  }

  Widget _body(AdminUserDetail d) {
    final u = d.user;
    final isOwner = u.role == 'studio_owner';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminCard(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.surfacePink,
                          foregroundImage: d.avatarUrl != null ? NetworkImage(d.avatarUrl!) : null,
                          child: Text(
                            u.fullName.trim().isEmpty ? '?' : u.fullName.trim().split(' ').last[0].toUpperCase(),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accentText),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.fullName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                              Text(u.email, style: const TextStyle(color: AppColors.textBody)),
                              Text(
                                '${AdminUserRow.roleLabel(u.role)} · tham gia ${fmtDate(u.createdAt)}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
                              ),
                            ],
                          ),
                        ),
                        if (u.isLocked)
                          const Chip(
                            avatar: Icon(Icons.lock_rounded, size: 16, color: AppColors.statusError),
                            label: Text('Đang bị khoá'),
                          ),
                      ],
                    ),
                  ],
                ),
                if (!isOwner) ...[
                  ResponsiveGrid(
                    minItemWidth: 180,
                    children: [
                      StatCard(icon: Icons.receipt_long_outlined, label: 'Tổng số đơn', value: '${d.totalBookings}'),
                      StatCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Buổi chụp hoàn thành',
                        value: '${d.bookingCounts['completed'] ?? 0}',
                      ),
                      StatCard(icon: Icons.payments_outlined, label: 'Đã chi (hoàn thành)', value: Formatters.vnd(d.totalSpent)),
                      StatCard(
                        icon: Icons.block_rounded,
                        label: 'Huỷ / không đến',
                        value: '${(d.bookingCounts['cancelled'] ?? 0) + (d.bookingCounts['no_show'] ?? 0)}',
                        highlight: (d.bookingCounts['no_show'] ?? 0) >= 2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AdminCard(
                    title: 'Đơn gần đây',
                    trailing: d.totalBookings > d.recentBookings.length
                        ? TextButton(
                            onPressed: () => AdminBookingsPage.open(context,
                                userId: u.id, title: 'Đơn của ${u.fullName}'),
                            child: Text('Xem tất cả ${d.totalBookings}'),
                          )
                        : null,
                    children: [
                      if (d.recentBookings.isEmpty)
                        const Text('Chưa đặt lịch lần nào.', style: TextStyle(color: AppColors.textBody)),
                      for (final b in d.recentBookings)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${b.studio} · ${b.set}'),
                          subtitle: Text(
                            '${fmtDate(b.start)} ${Formatters.hm(b.start)} · ${Formatters.vnd(b.amount)}'
                            '${(b.reason ?? '').isEmpty ? '' : '\nLý do: ${b.reason}'}',
                          ),
                          trailing: BookingStatusBadge(status: b.status),
                        ),
                    ],
                  ),
                  AdminCard(
                    title: 'Đánh giá đã viết (${d.reviews.length})',
                    children: [
                      if (d.reviews.isEmpty)
                        const Text('Chưa có đánh giá.', style: TextStyle(color: AppColors.textBody)),
                      for (final r in d.reviews)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${'★' * r.stars}${'☆' * (5 - r.stars)}  ${r.studio} · ${fmtDate(r.at)}',
                                  style: const TextStyle(color: AppColors.textTitle)),
                              if ((r.comment ?? '').trim().isNotEmpty)
                                Text(r.comment!.trim(), style: const TextStyle(color: AppColors.textBody)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                if (isOwner)
                  AdminCard(
                    title: 'Studio sở hữu (${d.studios.length})',
                    children: [
                      if (d.studios.isEmpty)
                        const Text('Chưa tạo studio.', style: TextStyle(color: AppColors.textBody)),
                      for (final s in d.studios)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.name),
                          subtitle: Text('${s.district} · ★ ${s.rating.toStringAsFixed(1)}'),
                          trailing: StudioStatusBadge(status: s.status),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AdminStudioDetailScreen(studioId: s.id)),
                          ),
                        ),
                    ],
                  ),
                if (d.bookingCounts.isNotEmpty && !isOwner)
                  AdminCard(
                    title: 'Đơn theo trạng thái',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in _statusLabels.entries)
                            if ((d.bookingCounts[e.key] ?? 0) > 0)
                              Chip(label: Text('${e.value}: ${d.bookingCounts[e.key]}')),
                        ],
                      ),
                    ],
                  ),
                AdminCard(
                  title: 'Lịch sử khoá / mở khoá',
                  children: [
                    if (d.history.isEmpty)
                      const Text('Chưa từng bị khoá.', style: TextStyle(color: AppColors.textBody)),
                    for (final h in d.history)
                      Text(
                        '${fmtDateTime(h.at)} · ${h.action} bởi ${h.admin}${(h.note ?? '').isEmpty ? '' : ' — ${h.note}'}',
                        style: const TextStyle(height: 1.6, color: AppColors.textBody),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
