import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản của tôi')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildGlowingAvatar(user?.fullName),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _roleLabel(user?.role),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Avatar bọc trong Container riêng, dùng BoxShadow với offset = Offset.zero
  /// (KHÔNG dùng `elevation` của Material) để tạo glow toả đều 4 phía, tránh
  /// lỗi "lệch bóng" đã gặp ở nút Login trước đó.
  Widget _buildGlowingAvatar(String? fullName) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.iceGlow.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.iceGlow.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.surfaceVariant,
        child: Text(
          (fullName?.isNotEmpty ?? false) ? fullName!.substring(0, 1).toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'user':
        return 'Khách hàng';
      case 'studio_owner':
        return 'Chủ Studio';
      case 'admin':
        return 'Quản trị viên';
      default:
        return '';
    }
  }
}
