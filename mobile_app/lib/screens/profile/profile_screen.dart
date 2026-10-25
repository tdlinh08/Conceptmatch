import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookings_provider.dart';
import '../../providers/favorites_provider.dart';

/// Tab "Cá nhân": thông tin tài khoản, số liệu nhanh, đăng xuất.
///
/// Chỉ hiện những gì đã có API thật. Đổi tên / đổi mật khẩu / ảnh đại diện
/// chưa có endpoint ở backend nên CHƯA đưa lên (tránh nút bấm vào không làm gì).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const String appVersion = '1.0.0'; // khớp "version" trong pubspec.yaml

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Đăng xuất?'),
        content: const Text(
          'Bạn sẽ cần đăng nhập lại để đặt lịch và xem lịch hẹn.',
          style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.statusError),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Đọc trước khi await: sau khi đăng xuất, màn này bị gỡ khỏi cây widget.
    final favorites = context.read<FavoritesProvider>();
    final bookings = context.read<BookingsProvider>();
    await context.read<AuthProvider>().logout();
    // Xoá dữ liệu của tài khoản vừa đăng xuất để người đăng nhập sau
    // không thấy danh sách đã lưu / lịch hẹn của người trước.
    favorites.reset();
    bookings.reset();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final bookings = context.watch<BookingsProvider>().myBookings;
    final savedCount = context.watch<FavoritesProvider>().favoriteIds.length;
    final bottomInset = MediaQuery.paddingOf(context).bottom; // chừa chỗ thanh điều hướng nổi

    final isCustomer = user?.role == 'user';
    final upcoming = bookings.where((b) => b.isUpcoming).length;
    final completed = bookings.where((b) => b.status == 'completed').length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
          children: [
            const Text(
              'Cá nhân',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 20),

            // ---- Thẻ tài khoản ----
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  _Avatar(fullName: user?.fullName ?? ''),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.textTitle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                        ),
                        const SizedBox(height: 8),
                        _RoleBadge(role: user?.role),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- Số liệu nhanh (chỉ tài khoản khách mới có lịch hẹn / đã lưu) ----
            if (isCustomer) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatTile(value: upcoming, label: 'Sắp tới')),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(value: completed, label: 'Đã chụp')),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(value: savedCount, label: 'Đã lưu')),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfacePink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Ứng dụng di động hiện dành cho khách đặt lịch. Màn quản lý studio sẽ được bổ sung ở giai đoạn sau.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textBody),
                ),
              ),
            ],

            const SizedBox(height: 28),
            const _GroupLabel('ỨNG DỤNG'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outline),
              ),
              child: const Column(
                children: [
                  _InfoRow(icon: Icons.info_outline_rounded, label: 'Phiên bản', value: appVersion),
                  Divider(height: 1, color: AppColors.outline, indent: 52),
                  _InfoRow(
                    icon: Icons.school_outlined,
                    label: 'Đồ án tốt nghiệp',
                    value: 'ĐH Kiến trúc Hà Nội',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Đăng xuất'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusError,
                side: BorderSide(color: AppColors.statusError.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Widget con
// =============================================================================

class _Avatar extends StatelessWidget {
  final String fullName;
  const _Avatar({required this.fullName});

  /// Người Việt gọi theo TÊN (chữ cuối), nên lấy chữ cái đầu của tên:
  /// "Trần Diệu Linh" -> "L" (bản cũ lấy chữ đầu của họ -> "T").
  String get _initial {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final given = parts.isEmpty ? '' : parts.last;
    return given.isEmpty ? '?' : given[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.moonPink, AppColors.dustyMauve],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textTitle,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String? role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      'user' => 'Khách hàng',
      'studio_owner' => 'Chủ studio',
      'admin' => 'Quản trị viên',
      _ => null,
    };
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfacePink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accentText,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final int value;
  final String label;
  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textFaint,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textFaint),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textTitle)),
          ),
          Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textBody)),
        ],
      ),
    );
  }
}