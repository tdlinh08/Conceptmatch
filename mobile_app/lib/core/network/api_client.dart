import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Bọc quanh Dio, dùng chung 1 instance duy nhất (singleton) cho toàn app.
/// Mọi Provider đều gọi qua `ApiClient().dio`, để token luôn được tự động gắn
/// vào request và tự động làm mới khi hết hạn.
///
/// CƠ CHẾ TỰ LÀM MỚI TOKEN:
/// - Access token sống 15 phút, refresh token sống 7 ngày (theo backend).
/// - Request nào bị 401 -> dùng refresh token gọi POST /auth/refresh lấy access
///   token mới -> gửi lại đúng request đó. Người dùng không thấy gì.
/// - Nếu refresh token cũng hết hạn/không hợp lệ -> xoá token, báo cho
///   AuthProvider qua [onSessionExpired] để đưa về màn đăng nhập.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  /// Dio RIÊNG chỉ để gọi /auth/refresh — không gắn interceptor, tránh vòng lặp
  /// "refresh bị 401 -> lại đi refresh -> ...".
  late final Dio _refreshDio;

  final _storage = const FlutterSecureStorage();

  /// AuthProvider gán hàm này để được báo khi phiên đăng nhập hết hạn hẳn.
  void Function()? onSessionExpired;

  /// Nhiều request cùng bị 401 một lúc chỉ refresh MỘT lần, các request còn lại
  /// chờ chung kết quả này.
  Future<String?>? _refreshing;

  /// Các API không được tự refresh khi 401 (sai mật khẩu cũng trả 401).
  static const _noRefreshPaths = ['/auth/login', '/auth/register', '/auth/refresh', '/auth/google'];

  ApiClient._internal() {
    final options = BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );
    dio = Dio(options);
    _refreshDio = Dio(options);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final shouldRefresh = error.response?.statusCode == 401 &&
              !_noRefreshPaths.contains(request.path) &&
              request.extra['retried'] != true; // mỗi request chỉ thử lại 1 lần

          if (!shouldRefresh) {
            handler.next(error);
            return;
          }

          final newToken = await _refreshAccessToken();
          if (newToken == null) {
            handler.next(error); // refresh thất bại -> trả lỗi 401 gốc
            return;
          }

          try {
            request.extra['retried'] = true;
            request.headers['Authorization'] = 'Bearer $newToken';
            final response = await dio.fetch(request);
            handler.resolve(response);
          } on DioException catch (e) {
            handler.next(e);
          }
        },
      ),
    );
  }

  /// Trả về access token mới, hoặc null nếu không làm mới được (khi đó đã xoá
  /// token và gọi [onSessionExpired]).
  Future<String?> _refreshAccessToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      await _expireSession();
      return null;
    }

    try {
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newToken = (response.data as Map<String, dynamic>)['access_token'] as String;
      await _storage.write(key: 'access_token', value: newToken);
      return newToken;
    } on DioException catch (e) {
      // Chỉ đăng xuất khi server KHẲNG ĐỊNH refresh token không còn hợp lệ.
      // Mất mạng / server tắt thì giữ nguyên token để thử lại lần sau.
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) await _expireSession();
      return null;
    }
  }

  Future<void> _expireSession() async {
    await clearTokens();
    onSessionExpired?.call();
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');

  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');
}