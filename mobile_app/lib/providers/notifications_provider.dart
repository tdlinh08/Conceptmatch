import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/notification_model.dart';

/// Thông báo trong app: số chưa đọc (chấm đỏ trên chuông ở Home) + danh sách.
class NotificationsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<AppNotification> items = [];
  int unread = 0;
  bool isLoading = false;
  String? errorMessage;

  /// Xoá dữ liệu của tài khoản cũ khi đăng xuất.
  void reset() {
    items = [];
    unread = 0;
    errorMessage = null;
    isLoading = false;
    notifyListeners();
  }

  /// Chỉ lấy số chưa đọc — gọi khi mở Home / quay lại Home (nhẹ, không tải danh sách).
  Future<void> fetchUnreadCount() async {
    try {
      final response = await _apiClient.dio.get('/notifications/unread-count');
      unread = (response.data as Map<String, dynamic>)['unread'] as int;
      notifyListeners();
    } catch (_) {
      // Chuông không có số cũng không sao, không làm phiền người dùng.
    }
  }

  Future<void> fetch() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get('/notifications', queryParameters: {'limit': 50});
      final data = response.data as Map<String, dynamic>;
      items = (data['data'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      unread = data['unread'] as int;
    } catch (_) {
      errorMessage = 'Không tải được thông báo. Kiểm tra lại kết nối.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    // Cập nhật ngay trên màn rồi mới gọi API, để chấm "chưa đọc" mất liền khi bấm
    items = [for (final x in items) x.id == n.id ? x.copyWith(isRead: true) : x];
    unread = unread > 0 ? unread - 1 : 0;
    notifyListeners();
    try {
      await _apiClient.dio.patch('/notifications/${n.id}/read');
    } catch (_) {
      // Lỗi mạng: lần mở sau sẽ đồng bộ lại theo server.
    }
  }

  Future<void> markAllRead() async {
    if (unread == 0) return;
    items = [for (final x in items) x.copyWith(isRead: true)];
    unread = 0;
    notifyListeners();
    try {
      await _apiClient.dio.patch('/notifications/read-all');
    } catch (_) {}
  }
}
