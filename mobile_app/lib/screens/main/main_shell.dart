import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../favorites/favorites_screen.dart';
import '../bookings/my_bookings_screen.dart';
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
    MyBookingsScreen(),
    ProfileScreen(),
  ];

  void _openAiSearch() {
    // Màn AI Visual Search sẽ làm ở bước sau — khi đó thay dòng dưới bằng:
    // Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSearchScreen()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Màn tìm bằng hình ảnh sẽ có ở bước tiếp theo')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody: nội dung cuộn chạy ra SAU thanh điều hướng nổi, không bị
      // cắt ngang thành một dải nền trống. Scaffold tự cộng chiều cao thanh vào
      // MediaQuery.padding.bottom, nên danh sách trong từng màn phải cộng
      // khoảng này vào padding đáy (xem bottomInset ở home_screen.dart).
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        onTabSelected: (index) => setState(() => _currentIndex = index),
        onAiPressed: _openAiSearch,
      ),
    );
  }
}

/// Thanh điều hướng nổi dạng viên thuốc + nút AI tròn ở giữa.
///
/// Cả khối cao [_slotHeight]: thanh 68px nằm ở đáy, nút AI nhô lên [_aiRise]px
/// phía trên thanh. Nút AI vẫn nằm TRONG khung của widget (không tràn ra ngoài), nhờ vậy
/// bấm vào nửa trên của nút vẫn nhận được.
class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAiPressed;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTabSelected,
    required this.onAiPressed,
  });

  static const double _barHeight = 68;
  static const double _bottomGap = 12;
  static const double _aiSize = 66; // gồm cả vòng viền 4px màu nền
  static const double _aiRise = 10; // phần nút AI nhô lên khỏi mép trên của thanh
  static const double _slotHeight = _barHeight + _bottomGap + _aiRise;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _slotHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // ---- Thanh viên thuốc ----
            Positioned(
              left: 16,
              right: 16,
              bottom: _bottomGap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.nightPlum.withValues(alpha: 0.14),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: _barHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(_barHeight / 2),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        children: [
                          _NavItem(
                            label: 'Khám phá',
                            icon: Icons.explore_outlined,
                            selectedIcon: Icons.explore,
                            selected: currentIndex == 0,
                            onTap: () => onTabSelected(0),
                          ),
                          _NavItem(
                            label: 'Đã lưu',
                            icon: Icons.favorite_border,
                            selectedIcon: Icons.favorite,
                            selected: currentIndex == 1,
                            onTap: () => onTabSelected(1),
                          ),
                          const SizedBox(width: _aiSize), // chừa chỗ cho nút AI
                          _NavItem(
                            label: 'Lịch hẹn',
                            icon: Icons.calendar_month_outlined,
                            selectedIcon: Icons.calendar_month,
                            selected: currentIndex == 2,
                            onTap: () => onTabSelected(2),
                          ),
                          _NavItem(
                            label: 'Cá nhân',
                            icon: Icons.person_outline,
                            selectedIcon: Icons.person,
                            selected: currentIndex == 3,
                            onTap: () => onTabSelected(3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ---- Nút AI tròn nổi ở giữa ----
            Positioned(
              top: 0,
              child: _AiButton(size: _aiSize, onPressed: onAiPressed),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentText : AppColors.textFaint;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút AI: chỗ DUY NHẤT trong app dùng gradient Moon Pink → Dusty Mauve.
class _AiButton extends StatelessWidget {
  final double size;
  final VoidCallback onPressed;

  const _AiButton({required this.size, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tìm studio bằng hình ảnh',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2), // vòng viền màu nền tách nút khỏi thanh
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.dustyMauve.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.moonPink, AppColors.dustyMauve],
              ),
            ),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: const Center(
                child: Icon(Icons.auto_awesome, size: 28, color: AppColors.textTitle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}