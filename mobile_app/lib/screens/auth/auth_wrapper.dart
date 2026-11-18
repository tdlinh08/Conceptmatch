import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/realtime_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'login_screen.dart';
import '../main/main_shell.dart';
import '../owner/owner_shell.dart';
import '../admin/admin_shell.dart';

/// Widget gốc quyết định hiển thị màn hình nào dựa theo trạng thái đăng nhập.
/// Đặt làm `home` của MaterialApp thay vì chỉ định thẳng LoginScreen, để tự
/// động chuyển màn hình khi AuthProvider.status đổi (không cần Navigator thủ
/// công ở LoginScreen sau khi đăng nhập thành công).
///
/// Đồng thời mở / đóng kết nối real-time (chat + thông báo) theo phiên đăng nhập.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  /// id người dùng đang có kết nối real-time (null = chưa đăng nhập / admin).
  String? _realtimeUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kiểm tra token đã lưu sẵn ngay khi app khởi động (giữ đăng nhập qua
    // các lần mở app, không bắt đăng nhập lại mỗi lần).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuthStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Mở lại app sau khi để nền: kết nối socket có thể đã đứt -> nối lại.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _realtimeUserId != null &&
        !RealtimeClient().connected.value) {
      RealtimeClient().connect();
    }
  }

  /// Khách và chủ studio có chat + thông báo real-time; admin không cần.
  void _syncRealtime(AuthProvider auth) {
    final user = auth.status == AuthStatus.authenticated ? auth.currentUser : null;
    final id = (user == null || user.role == 'admin') ? null : user.id;
    if (id == _realtimeUserId) return;
    _realtimeUserId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chat = context.read<ChatProvider>();
      if (id == null) {
        RealtimeClient().disconnect();
        chat.reset();
      } else {
        RealtimeClient().connect();
        chat.start(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    _syncRealtime(auth);

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        // Mỗi vai trò một khung app. Key theo vai trò: đổi tài khoản khác vai trò thì dựng lại từ đầu.
        return switch (auth.currentUser?.role) {
          'studio_owner' => const OwnerShell(key: ValueKey('owner')),
          'admin' => const AdminShell(key: ValueKey('admin')), // web (máy tính) hoặc điện thoại
          _ => const MainShell(key: ValueKey('customer')),
        };
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
