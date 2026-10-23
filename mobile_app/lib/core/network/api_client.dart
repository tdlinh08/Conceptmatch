import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Bọc quanh Dio, dùng chung 1 instance duy nhất (singleton) cho toàn app.
/// Mọi Provider (AuthProvider, StudiosProvider...) sau này đều gọi qua
/// `ApiClient().dio` thay vì tự tạo Dio riêng, để đảm bảo token luôn được
/// tự động gắn vào mọi request không cần lặp lại code.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

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
          // TODO: xử lý tự động refresh access token khi gặp lỗi 401,
          // sẽ hoàn thiện đầy đủ khi xây AuthProvider (bước tiếp theo).
          handler.next(error);
        },
      ),
    );
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
