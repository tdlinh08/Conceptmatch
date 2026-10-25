import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/booking_models.dart';

/// Lỗi nghiệp vụ khi đặt lịch, mang sẵn câu thông báo tiếng Việt để hiển thị.
class BookingException implements Exception {
  final String message;
  final int? statusCode;

  BookingException(this.message, {this.statusCode});

  /// 409 = khung giờ vừa bị người khác đặt mất (chống double-booking ở backend).
  bool get isSlotTaken => statusCode == 409;

  @override
  String toString() => message;
}

/// Đặt lịch. Hiện chỉ gọi API; danh sách "Lịch hẹn của tôi" sẽ thêm vào đây
/// ở bước My Bookings (khi đó mới cần notifyListeners).
class BookingsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  /// Các khung 1 giờ còn trống của [setId] trong ngày [date].
  Future<AvailabilityResult> fetchAvailability({
    required String studioId,
    required String setId,
    required DateTime date,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/studios/$studioId/availability',
        queryParameters: {'date': formatApiDate(date), 'set_id': setId},
      );
      return AvailabilityResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toBookingException(e);
    }
  }

  /// Tạo đơn đặt lịch từ giờ [startHour] đến [endHour] (vd 14 -> 16 là 2 tiếng).
  Future<CreatedBooking> createBooking({
    required String studioId,
    required String setId,
    required DateTime date,
    required int startHour,
    required int endHour,
    String? note,
  }) async {
    final day = formatApiDate(date);
    try {
      final response = await _apiClient.dio.post(
        '/bookings',
        data: {
          'studio_id': studioId,
          'set_id': setId,
          // Không kèm múi giờ: backend hiểu theo giờ địa phương của máy chủ (VN)
          'start_time': '${day}T${_two(startHour)}:00:00',
          'end_time': '${day}T${_two(endHour)}:00:00',
          if (note != null && note.trim().isNotEmpty) 'special_note': note.trim(),
        },
      );
      return CreatedBooking.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toBookingException(e);
    }
  }

  // ---- Tiện ích ----

  static String formatApiDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  BookingException _toBookingException(DioException e) {
    final code = e.response?.statusCode;

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return BookingException('Không thể kết nối tới server. Kiểm tra lại mạng.');
    }
    if (code == 401) {
      return BookingException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng xuất rồi đăng nhập lại.',
        statusCode: code,
      );
    }
    if (code == 403) {
      return BookingException('Tài khoản này không có quyền đặt lịch.', statusCode: code);
    }

    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      return BookingException(msg is List ? msg.join(', ') : msg.toString(), statusCode: code);
    }
    return BookingException('Đã có lỗi xảy ra, vui lòng thử lại.', statusCode: code);
  }
}