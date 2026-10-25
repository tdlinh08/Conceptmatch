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