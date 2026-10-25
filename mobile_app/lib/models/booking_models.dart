/// Một khung 1 giờ còn trống, trả về từ GET /studios/:id/availability.
class AvailableSlot {
  final int hour; // giờ bắt đầu, vd 8 cho "08:00"
  final String start; // "08:00"
  final String end; // "09:00"
  final double? price; // null = studio chưa cấu hình giá cho khung này -> không đặt được

  AvailableSlot({required this.hour, required this.start, required this.end, this.price});

  factory AvailableSlot.fromJson(Map<String, dynamic> json) {
    final start = json['start'] as String;
    return AvailableSlot(
      hour: int.parse(start.split(':').first),
      start: start,
      end: json['end'] as String,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

class AvailabilityResult {
  final String date; // "YYYY-MM-DD"
  final String setId;
  final List<AvailableSlot> slots;

  AvailabilityResult({required this.date, required this.setId, required this.slots});

  factory AvailabilityResult.fromJson(Map<String, dynamic> json) {
    return AvailabilityResult(
      date: json['date'] as String,
      setId: json['set_id'] as String,
      slots: (json['available_slots'] as List)
          .map((e) => AvailableSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Đơn vừa tạo, trả về từ POST /bookings.
class CreatedBooking {
  final String id;
  final String status;
  final double totalAmount;
  final double depositAmount;

  CreatedBooking({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.depositAmount,
  });

  factory CreatedBooking.fromJson(Map<String, dynamic> json) {
    return CreatedBooking(
      id: json['id'] as String,
      status: json['status'] as String,
      // Kiểu Decimal của Prisma trả về dạng chuỗi -> parse qua toString()
      totalAmount: double.parse(json['total_amount'].toString()),
      depositAmount: double.parse(json['deposit_amount'].toString()),
    );
  }
}

/// Một đơn trong danh sách "Lịch hẹn của tôi" (GET /bookings).
class BookingSummary {
  final String id;
  final String studioId;
  final String studioName;
  final String? coverImage;
  final String setName;
  final DateTime startTime;
  final DateTime endTime;
  final double totalAmount;
  final double depositAmount;
  final String status; // pending | confirmed | checked_in | completed | cancelled | rejected | no_show
  final bool hasReview;
  final DateTime createdAt;

  BookingSummary({
    required this.id,
    required this.studioId,
    required this.studioName,
    this.coverImage,
    required this.setName,
    required this.startTime,
    required this.endTime,
    required this.totalAmount,
    required this.depositAmount,
    required this.status,
    required this.hasReview,
    required this.createdAt,
  });

  /// Còn hiệu lực, chưa diễn ra xong.
  bool get isUpcoming => const ['pending', 'confirmed', 'checked_in'].contains(status);

  /// Đã kết thúc (hoàn thành hoặc khách vắng mặt).
  bool get isFinished => const ['completed', 'no_show'].contains(status);

  /// Bị huỷ (khách tự huỷ hoặc studio từ chối).
  bool get isCancelled => const ['cancelled', 'rejected'].contains(status);

  /// Backend chỉ cho khách huỷ khi đơn còn "Chờ xác nhận".
  bool get canCancel => status == 'pending';

  /// Chỉ đơn đã hoàn thành và chưa đánh giá mới được đánh giá.
  bool get canReview => status == 'completed' && !hasReview;

  BookingSummary copyWith({String? status, bool? hasReview}) => BookingSummary(
        id: id,
        studioId: studioId,
        studioName: studioName,
        coverImage: coverImage,
        setName: setName,
        startTime: startTime,
        endTime: endTime,
        totalAmount: totalAmount,
        depositAmount: depositAmount,
        status: status ?? this.status,
        hasReview: hasReview ?? this.hasReview,
        createdAt: createdAt,
      );

  factory BookingSummary.fromJson(Map<String, dynamic> json) {
    return BookingSummary(
      id: json['id'] as String,
      studioId: json['studio_id'] as String,
      studioName: json['studio_name'] as String,
      coverImage: json['cover_image'] as String?,
      setName: json['set_name'] as String,
      // Backend lưu và trả giờ dạng UTC -> đổi về giờ máy (VN) để hiển thị.
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      totalAmount: double.parse(json['total_amount'].toString()),
      depositAmount: double.parse(json['deposit_amount'].toString()),
      status: json['status'] as String,
      hasReview: json['has_review'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}