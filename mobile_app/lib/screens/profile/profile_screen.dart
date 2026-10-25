import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookings_provider.dart';
import '../../providers/favorites_provider.dart';
import 'profile_edit_sheets.dart';

/// Tab "Cá nhân": thông tin tài khoản, số liệu nhanh, chỉnh sửa hồ sơ, đăng xuất.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const String appVersion = '1.0.0'; // khớp "version" trong pubspec.yaml

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeAvatar() async {
    if (_uploadingAvatar) return;

    final String? path;
    try {
      path = await pickAvatarImage(context);
    } on AvatarPickException catch (e) {
      if (mounted) _toast(e.message);
      return;
    }
    if (path == null || !mounted) return; // người dùng huỷ

    setState(() => _uploadingAvatar = true);
    final error = await context.read<AuthProvider>().uploadAvatar(path);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    _toast(error ?? 'Đã cập nhật ảnh đại diện');
  }

  Future<void> _editName() async {
    final ok = await showEditNameSheet(context);
    if (ok == true && mounted) _toast('Đã cập nhật họ tên');
  }

  Future<void> _changePassword() async {
    final ok = await showChangePasswordSheet(context);
    if (ok == true && mounted) _toast('Đã đổi mật khẩu');
  }

  Future<void> _confirmLogout() async {
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
    if (confirmed != true || !mounted) return;

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
                  _Avatar(
                    fullName: user?.fullName ?? '',
                    imageUrl: ApiConstants.mediaUrl(user?.avatarUrl),
                    uploading: _uploadingAvatar,
                    onTap: _changeAvatar,
                  ),
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
            const SizedBox(height: 12),
            if (isCustomer)
              Row(
                children: [
                  Expanded(child: _StatTile(value: upcoming, label: 'Sắp tới')),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(value: completed, label: 'Đã chụp')),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(value: savedCount, label: 'Đã lưu')),
                ],
              )
            else
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

            // ---- Tài khoản ----
            const SizedBox(height: 28),
            const _GroupLabel('TÀI KHOẢN'),
            const SizedBox(height: 10),
            _Group(
              children: [
                _MenuRow(
                  icon: Icons.badge_outlined,
                  label: 'Họ và tên',
                  value: user?.fullName,
                  onTap: _editName,
                ),
                _MenuRow(
                  icon: Icons.account_circle_outlined,
                  label: 'Ảnh đại diện',
                  onTap: _changeAvatar,
                ),
                if (user?.hasPassword ?? true)
                  _MenuRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Đổi mật khẩu',
                    onTap: _changePassword,
                  ),
                _MenuRow(icon: Icons.mail_outline_rounded, label: 'Email', value: user?.email),
              ],
            ),

            // ---- Ứng dụng ----
            const SizedBox(height: 28),
            const _GroupLabel('ỨNG DỤNG'),
            const SizedBox(height: 10),
            const _Group(
              children: [
                _MenuRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Phiên bản',
                  value: ProfileScreen.appVersion,
                ),
                _MenuRow(
                  icon: Icons.school_outlined,
                  label: 'Đồ án tốt nghiệp',
                  value: 'ĐH Kiến trúc Hà Nội',
                ),
              ],
            ),

            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _confirmLogout,
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
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onTap;

  const _Avatar({
    required this.fullName,
    required this.imageUrl,
    required this.uploading,
    required this.onTap,
  });

  /// Người Việt gọi theo TÊN (chữ cuối): "Trần Diệu Linh" -> "L".
  String get _initial {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final given = parts.isEmpty ? '' : parts.last;
    return given.isEmpty ? '?' : given[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initialCircle = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.moonPink, AppColors.dustyMauve],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textTitle),
      ),
    );

    return Semantics(
      button: true,
      label: 'Đổi ảnh đại diện',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: uploading ? null : onTap,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: imageUrl == null
                      ? initialCircle
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => initialCircle,
                        ),
                ),
              ),
              if (uploading)
                const ClipOval(
                  child: ColoredBox(
                    color: Color(0x80FFFFFF),
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                  ),
                ),
              // Huy hiệu máy ảnh nhỏ ở góc: gợi ý "bấm vào để đổi ảnh".
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 12, color: AppColors.onPrimary),
                ),
              ),
            ],
          ),
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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentText),
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textTitle),
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

/// Khối trắng bo góc chứa các dòng, tự chèn đường kẻ giữa các dòng.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.outline, indent: 52),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Một dòng trong khối: có [onTap] thì hiện mũi tên và bấm được.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const _MenuRow({required this.icon, required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textFaint),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textTitle)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, color: AppColors.textBody),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textFaint),
            ],
          ],
        ),
      ),
    );
  }
}
