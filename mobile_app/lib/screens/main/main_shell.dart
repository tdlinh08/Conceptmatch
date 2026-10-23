import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../favorites/favorites_screen.dart';
import '../bookings/my_bookings_placeholder_screen.dart';
import '../profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    FavoritesScreen(),
    MyBookingsPlaceholderScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      // Bọc trong Container riêng để thêm vạch kẻ mỏng phía trên — thay cho
      // cả khối màu đặc, giúp Bottom Nav hoà vào nền thay vì "kéo mắt xuống
      // đáy" như trước.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.6),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Khám phá'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Yêu thích'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Đặt lịch'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
          ],
        ),
      ),
    );
  }
}
