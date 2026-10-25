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

/// Đặt lịch, danh sách "Lịch hẹn của tôi", huỷ lịch, đánh giá.
class BookingsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // ---- Lịch hẹn của tôi ----
  List<BookingSummary> myBookings = [];
  bool isLoadingMine = false;
  String? mineError;
  bool _loadedOnce = false;
  bool get hasLoadedMine => _loadedOnce;

  /// Xoá lịch hẹn của tài khoản cũ khi đăng xuất (xem FavoritesProvider.reset).
  void reset() {
    myBookings = [];
    mineError = null;
    isLoadingMine = false;
    _loadedOnce = false;
    notifyListeners();
  }

  /// Tải toàn bộ lịch hẹn (tối đa 100 đơn gần nhất) rồi chia tab ở phía app.
  Future<void> fetchMyBookings() async {
    isLoadingMine = true;
    mineError = null;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get('/bookings', queryParameters: {'limit': 100});
      final data = response.data as Map<String, dynamic>;
      myBookings = (data['data'] as List)
          .map((e) => BookingSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      _loadedOnce = true;
    } on DioException catch (e) {
      mineError = _toBookingException(e).message;
    } finally {
      isLoadingMine = false;
      notifyListeners();
    }
  }

  /// Khách huỷ đơn đang "Chờ xác nhận" (DELETE /bookings/:id).
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _apiClient.dio.delete('/bookings/$bookingId');
    } on DioException catch (e) {
      throw _toBookingException(e);
    }
    _updateLocal(bookingId, (b) => b.copyWith(status: 'cancelled'));
  }

  /// Gửi đánh giá cho đơn đã hoàn thành (POST /reviews).
  Future<void> submitReview({
    required String bookingId,
    required int stars,
    String? comment,
  }) async {
    try {
      await _apiClient.dio.post('/reviews', data: {
        'booking_id': bookingId,
        'stars': stars,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });
    } on DioException catch (e) {
      throw _toBookingException(e);
    }
    _updateLocal(bookingId, (b) => b.copyWith(hasReview: true));
  }

  void _updateLocal(String id, BookingSummary Function(BookingSummary) change) {
    myBookings = [for (final b in myBookings) b.id == id ? change(b) : b];
    notifyListeners();
  }

  // ---- Đặt lịch ----

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
      final created = CreatedBooking.fromJson(response.data as Map<String, dynamic>);
      // Tab "Lịch hẹn" giữ trạng thái suốt phiên (IndexedStack) nên phải chủ
      // động tải lại để đơn mới hiện ngay, không cần kéo để làm mới.
      if (_loadedOnce) fetchMyBookings();
      return created;
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