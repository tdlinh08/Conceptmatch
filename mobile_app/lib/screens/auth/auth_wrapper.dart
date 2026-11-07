import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import '../main/main_shell.dart';
import '../owner/owner_shell.dart';

/// Widget gốc quyết định hiển thị màn hình nào dựa theo trạng thái đăng nhập.
/// Đặt làm `home` của MaterialApp thay vì chỉ định thẳng LoginScreen, để tự
/// động chuyển màn hình khi AuthProvider.status đổi (không cần Navigator thủ
/// công ở LoginScreen sau khi đăng nhập thành công).
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Kiểm tra token đã lưu sẵn ngay khi app khởi động (giữ đăng nhập qua
    // các lần mở app, không bắt đăng nhập lại mỗi lần).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final status = auth.status;

    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        // Chủ studio -> app quản lý studio; khách (và admin, chưa có app riêng) -> app đặt lịch.
        // Key theo vai trò: đổi tài khoản khác vai trò thì dựng lại khung từ đầu.
        return auth.currentUser?.role == 'studio_owner'
            ? const OwnerShell(key: ValueKey('owner'))
            : const MainShell(key: ValueKey('customer'));
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
