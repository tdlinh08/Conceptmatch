import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import 'admin_audit_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_studios_page.dart';
import 'admin_users_page.dart';

/// Khung trang QUẢN TRỊ. Màn hình rộng (trình duyệt máy tính) -> thanh điều hướng bên trái;
/// màn hình hẹp (điện thoại) -> thanh điều hướng dưới. Cùng một mã nguồn cho web và app.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  final _dashboardKey = GlobalKey<AdminDashboardPageState>();
  final _studiosKey = GlobalKey<AdminStudiosPageState>();
  final _usersKey = GlobalKey<AdminUsersPageState>();
  final _auditKey = GlobalKey<AdminAuditPageState>();
  late final List<Widget> _pages = [
    AdminDashboardPage(key: _dashboardKey, onOpenPending: () => _select(1)),
    AdminStudiosPage(key: _studiosKey),
    AdminUsersPage(key: _usersKey),
    AdminAuditPage(key: _auditKey),
  ];

  /// IndexedStack giữ các trang -> chủ động tải lại khi chuyển sang.
  void _select(int i) {
    setState(() => _index = i);
    switch (i) {
      case 0:
        _dashboardKey.currentState?.load();
      case 1:
        _studiosKey.currentState?.load();
      case 2:
        _usersKey.currentState?.load();
      case 3:
        _auditKey.currentState?.load();
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ở lại')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.statusError),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final admin = context.read<AdminProvider>();
    await context.read<AuthProvider>().logout();
    admin.reset();
  }

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<AdminProvider>().pendingStudios;
    final user = context.watch<AuthProvider>().currentUser;

    Widget studioIcon(IconData icon) => Badge(
          isLabelVisible: pending > 0,
          label: Text('$pending'),
          child: Icon(icon),
        );

    final items = [
      (const Icon(Icons.dashboard_outlined), const Icon(Icons.dashboard), 'Tổng quan'),
      (studioIcon(Icons.storefront_outlined), studioIcon(Icons.storefront), 'Studio'),
      (const Icon(Icons.people_alt_outlined), const Icon(Icons.people_alt), 'Người dùng'),
      (const Icon(Icons.history_outlined), const Icon(Icons.history), 'Nhật ký'),
    ];
    final body = IndexedStack(index: _index, children: _pages);

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 800) {
          // ---- Máy tính / máy tính bảng ngang ----
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: c.maxWidth >= 1200,
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  backgroundColor: AppColors.surface,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Image.asset('assets/images/logo.png', width: 40, height: 40),
                        const SizedBox(height: 6),
                        const Text(
                          'Quản trị',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textTitle),
                        ),
                      ],
                    ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.maxWidth >= 1200 && user != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  user.fullName,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Đăng xuất',
                              onPressed: _logout,
                              icon: const Icon(Icons.logout_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  destinations: [
                    for (final (icon, selected, label) in items)
                      NavigationRailDestination(
                        icon: icon,
                        selectedIcon: selected,
                        label: Text(label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        // ---- Điện thoại ----
        return Scaffold(
          appBar: AppBar(
            title: const Text('Quản trị ConceptMatch'),
            actions: [
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: [
              for (final (icon, selected, label) in items)
                NavigationDestination(icon: icon, selectedIcon: selected, label: label),
            ],
          ),
        );
      },
    );
  }
}
