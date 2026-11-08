import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/owner_bookings_provider.dart';
import '../../providers/owner_studios_provider.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'my_studios_screen.dart';
import 'owner_booking_detail_screen.dart';
import 'owner_bookings_screen.dart';
import 'owner_revenue_screen.dart';
import 'owner_studio_detail_screen.dart';

/// Khung app của CHỦ STUDIO: Lịch đặt · Studio · Thông báo · Cá nhân.
/// Dùng thanh điều hướng chuẩn (không có nút AI như phía khách).
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  static const _bookingsTab = 0;
  static const _studiosTab = 1;
  static const _revenueTab = 2;
  static const _notificationsTab = 3;
  final _revenueKey = GlobalKey<OwnerRevenueScreenState>();

  int _index = _bookingsTab;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const OwnerBookingsScreen(),
      const MyStudiosScreen(),
      OwnerRevenueScreen(key: _revenueKey),
      NotificationsScreen(onOpen: _openNotification),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OwnerStudiosProvider>().fetchMine();
      context.read<NotificationsProvider>().fetchUnreadCount();
    });
  }

  /// Thông báo đơn đặt / đánh giá -> mở chi tiết đơn; studio được duyệt / bị từ chối -> mở studio đó.
  void _openNotification(AppNotification n) {
    if (n.refId == null) return;
    final Widget screen;
    if (n.type.startsWith('studio_')) {
      screen = OwnerStudioDetailScreen(studioId: n.refId!);
    } else if (n.opensBooking) {
      screen = OwnerBookingDetailScreen(bookingId: n.refId!);
    } else {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// IndexedStack giữ nguyên các tab -> chủ động tải lại khi chuyển tab.
  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    switch (index) {
      case _bookingsTab:
        context.read<OwnerStudiosProvider>().fetchMine();
        context.read<OwnerBookingsProvider>().refreshAll();
      case _studiosTab:
        context.read<OwnerStudiosProvider>().fetchMine();
      case _revenueTab:
        _revenueKey.currentState?.load();
      case _notificationsTab:
        context.read<NotificationsProvider>().fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationsProvider>().unread;
    final pending = context.watch<OwnerStudiosProvider>().pendingBookingCount;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.event_note_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.event_note),
            ),
            label: 'Lịch đặt',
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Studio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Doanh thu',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Thông báo',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}
