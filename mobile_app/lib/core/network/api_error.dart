import 'package:dio/dio.dart';

/// Lấy câu báo lỗi tiếng Việt từ lỗi gọi API (backend trả { message } hoặc { message: [...] }).
String apiErrorMessage(Object error, {String fallback = 'Có lỗi xảy ra, vui lòng thử lại'}) {
  if (error is! DioException) return fallback;
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
      return 'Không kết nối được máy chủ. Kiểm tra mạng / địa chỉ IP rồi thử lại.';
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Máy chủ phản hồi quá lâu, vui lòng thử lại.';
    default:
      break;
  }
  if (error.response?.statusCode == 413) return 'Ảnh quá lớn (tối đa 8MB mỗi ảnh).';
  final data = error.response?.data;
  if (data is Map && data['message'] != null) {
    final msg = data['message'];
    return msg is List ? msg.join(', ') : msg.toString();
  }
  return fallback;
}
