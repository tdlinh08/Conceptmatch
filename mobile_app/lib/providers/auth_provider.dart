import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  AuthStatus status = AuthStatus.unknown;
  UserModel? currentUser;
  String? errorMessage;
  bool isLoading = false;

  AuthProvider() {
    // ApiClient báo về đây khi refresh token cũng hết hạn (sau 7 ngày) hoặc bị
    // thu hồi (đã đăng xuất ở nơi khác) -> đưa người dùng về màn đăng nhập.
    _apiClient.onSessionExpired = _handleSessionExpired;
  }

  void _handleSessionExpired() {
    if (status == AuthStatus.unauthenticated) return;
    currentUser = null;
    status = AuthStatus.unauthenticated;
    errorMessage = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
    notifyListeners();
  }

  /// Gọi lúc app khởi động: kiểm tra đã có token lưu sẵn chưa. Nếu có, gọi
  /// GET /auth/me để lấy lại thông tin user — vì token không tự chứa đủ
  /// thông tin hiển thị (tên, vai trò...), và app có thể đã bị đóng/mở lại
  /// nhiều lần giữa các phiên làm việc.
  Future<void> checkAuthStatus() async {
    final token = await _apiClient.getAccessToken();
    if (token == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      // Access token đã hết hạn (vd: mở lại app sau vài giờ) thì ApiClient tự
      // dùng refresh token lấy token mới rồi gọi lại /auth/me — không bắt
      // đăng nhập lại chừng nào refresh token (7 ngày) còn hạn.
      final response = await _apiClient.dio.get('/auth/me');
      currentUser = UserModel.fromJson(response.data as Map<String, dynamic>);
      status = AuthStatus.authenticated;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        // Cả 2 token đều không dùng được nữa -> xoá hẳn.
        await _apiClient.clearTokens();
      }
      // Lỗi mạng (server chưa bật, sai IP...) thì GIỮ token, chỉ hiện màn đăng
      // nhập; lần mở app sau server chạy lại là vào thẳng được.
      status = AuthStatus.unauthenticated;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.dio.post('/auth/register', data: {
        'full_name': fullName,
        'email': email,
        'password': password,
      });
      isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      errorMessage = _extractErrorMessage(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = response.data as Map<String, dynamic>;

      await _apiClient.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      status = AuthStatus.authenticated;
      isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      errorMessage = _extractErrorMessage(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (_) {
      // Vẫn xoá token local dù gọi API logout thất bại (vd: mất mạng) —
      // ưu tiên đảm bảo người dùng thoát được khỏi phiên đăng nhập trên app,
      // kể cả khi không báo được cho server.
    }
    await _apiClient.clearTokens();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      if (msg is List) return msg.join(', ');
      return msg.toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Không thể kết nối tới server. Kiểm tra lại mạng hoặc địa chỉ IP trong api_constants.dart.';
    }
    return 'Đã có lỗi xảy ra, vui lòng thử lại.';
  }
}