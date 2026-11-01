import '../core/constants/api_constants.dart';
import '../core/utils/formatters.dart';

/// Một dịch vụ thêm trong đơn (thợ ảnh / trang điểm) + người được phân công.
class BookingAddonLine {
  final String name;
  final String role; // photographer | makeup
  final double quantity; // số lượt / số giờ / số người
  final double amount;
  final String? staffName; // null khi studio chưa xác nhận đơn

  BookingAddonLine({
    required this.name,
    required this.role,
    required this.quantity,
    required this.amount,
    this.staffName,
  });

  static List<BookingAddonLine> listFrom(Object? json) => ((json as List?) ?? const [])
      .map((e) => BookingAddonLine.fromJson(e as Map<String, dynamic>))
      .toList();

  factory BookingAddonLine.fromJson(Map<String, dynamic> json) {
    final staff = json['staff'] as Map<String, dynamic>?;
    return BookingAddonLine(
      name: json['name'] as String,
      role: json['role'] as String,
      quantity: Formatters.money(json['quantity']),
      amount: Formatters.money(json['amount']),
      staffName: staff?['full_name'] as String?,
    );
  }
}

/// Một GIỜ BẮT ĐẦU còn trống cho gói đã chọn (GET /studios/:id/availability).
/// Giờ bắt đầu cách nhau 30 phút; [price] đã gồm số người + phụ thu do backend tính.
class AvailableSlot {
  final String start; // "09:30"
  final String end; // "11:30" (= start + thời lượng gói)
  final double price;
  final int surchargePct; // 0 = không phụ thu

  AvailableSlot({
    required this.start,
    required this.end,
    required this.price,
    required this.surchargePct,
  });

  factory AvailableSlot.fromJson(Map<String, dynamic> json) {
    return AvailableSlot(
      start: json['start'] as String,
      end: json['end'] as String,
      price: Formatters.money(json['price']),
      surchargePct: json['surcharge_pct'] as int? ?? 0,
    );
  }
}

class AvailabilityResult {
  final String date; // "YYYY-MM-DD"
  final String packageId;
  final int numPeople;
  final double addonsAmount; // tiền dịch vụ thêm đã cộng sẵn trong từng giờ
  final String openTime;
  final String closeTime;
  final List<AvailableSlot> slots;

  AvailabilityResult({
    required this.date,
    required this.packageId,
    required this.numPeople,
    required this.addonsAmount,
    required this.openTime,
    required this.closeTime,
    required this.slots,
  });

  factory AvailabilityResult.fromJson(Map<String, dynamic> json) {
    return AvailabilityResult(
      date: json['date'] as String,
      packageId: json['package_id'] as String,
      numPeople: json['num_people'] as int,
      addonsAmount: Formatters.moneyOrNull(json['addons_amount']) ?? 0,
      openTime: json['open_time'] as String,
      closeTime: json['close_time'] as String,
      slots: (json['available_slots'] as List)
          .map((e) => AvailableSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Đơn vừa tạo, trả về từ POST /bookings — giá do BACKEND tính (app không gửi giá).
class CreatedBooking {
  final String id;
  final String status;
  final String? packageName;
  final int numPeople;
  final DateTime startTime;
  final DateTime endTime;
  final double? baseAmount; // giá gói
  final double? extraPeopleAmount; // phụ thu người thêm
  final double? surchargeAmount; // phụ thu giờ tối / cuối tuần
  final List<BookingAddonLine> addons;
  final double totalAmount;
  final double depositAmount;

  CreatedBooking({
    required this.id,
    required this.status,
    this.packageName,
    required this.numPeople,
    required this.startTime,
    required this.endTime,
    this.baseAmount,
    this.extraPeopleAmount,
    this.surchargeAmount,
    required this.addons,
    required this.totalAmount,
    required this.depositAmount,
  });

  factory CreatedBooking.fromJson(Map<String, dynamic> json) {
    return CreatedBooking(
      id: json['id'] as String,
      status: json['status'] as String,
      packageName: json['package_name'] as String?,
      numPeople: json['num_people'] as int? ?? 1,
      // Backend trả giờ dạng UTC -> đổi về giờ máy (VN)
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      baseAmount: Formatters.moneyOrNull(json['base_amount']),
      extraPeopleAmount: Formatters.moneyOrNull(json['extra_people_amount']),
      surchargeAmount: Formatters.moneyOrNull(json['surcharge_amount']),
      addons: BookingAddonLine.listFrom(json['addons']),
      totalAmount: Formatters.money(json['total_amount']),
      depositAmount: Formatters.money(json['deposit_amount']),
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
  final String? packageName; // null với đơn đặt trước khi có mô hình gói
  final int numPeople;
  final List<BookingAddonLine> addons;
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
    this.packageName,
    required this.numPeople,
    this.addons = const [],
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

  /// "Set Retro · Gói 2 tiếng · 3 người" (đơn cũ không có gói thì chỉ hiện tên set).
  String get detailLine {
    final parts = <String>[setName];
    if (packageName != null && packageName!.isNotEmpty) {
      parts.add(packageName!);
      parts.add('$numPeople người');
    }
    return parts.join(' · ');
  }

  /// "Thợ ảnh: An · Trang điểm: chờ studio phân công" (rỗng nếu đơn không có dịch vụ).
  String get staffLine => addons
      .map((a) => '${a.role == 'makeup' ? 'Trang điểm' : 'Thợ ảnh'}: ${a.staffName ?? 'chờ phân công'}')
      .join(' · ');

  BookingSummary copyWith({String? status, bool? hasReview}) => BookingSummary(
        id: id,
        studioId: studioId,
        studioName: studioName,
        coverImage: coverImage,
        setName: setName,
        packageName: packageName,
        numPeople: numPeople,
        addons: addons,
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
      coverImage: ApiConstants.mediaUrl(json['cover_image'] as String?),
      setName: json['set_name'] as String,
      packageName: json['package_name'] as String?,
      numPeople: json['num_people'] as int? ?? 1,
      addons: BookingAddonLine.listFrom(json['addons']),
      // Backend lưu và trả giờ dạng UTC -> đổi về giờ máy (VN) để hiển thị.
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      totalAmount: Formatters.money(json['total_amount']),
      depositAmount: Formatters.money(json['deposit_amount']),
      status: json['status'] as String,
      hasReview: json['has_review'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
