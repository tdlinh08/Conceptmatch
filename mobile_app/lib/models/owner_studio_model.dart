import '../core/constants/api_constants.dart';

/// Trạng thái duyệt của studio (khớp enum StudioStatus ở backend).
class StudioStatus {
  static const pending = 'pending';
  static const active = 'active';
  static const rejected = 'rejected';

  static String label(String status) => switch (status) {
        StudioStatus.pending => 'Chờ duyệt',
        StudioStatus.active => 'Đang hoạt động',
        StudioStatus.rejected => 'Bị từ chối',
        _ => status,
      };
}

/// 1 dòng trong "Studio của tôi" (GET /studios/mine).
class OwnerStudioSummary {
  final String id;
  final String name;
  final String district;
  final String address;
  final String status;
  final String? rejectReason;
  final String? coverImage; // địa chỉ đầy đủ
  final double avgRating;
  final int reviewCount;
  final int setCount;
  final int imageCount;
  final int pendingBookingCount;

  OwnerStudioSummary({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.status,
    this.rejectReason,
    this.coverImage,
    required this.avgRating,
    required this.reviewCount,
    required this.setCount,
    required this.imageCount,
    required this.pendingBookingCount,
  });

  factory OwnerStudioSummary.fromJson(Map<String, dynamic> json) => OwnerStudioSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        district: json['district'] as String,
        address: json['address'] as String,
        status: json['status'] as String,
        rejectReason: json['reject_reason'] as String?,
        coverImage: ApiConstants.mediaUrl(json['cover_image'] as String?),
        avgRating: (json['avg_rating'] as num? ?? 0).toDouble(),
        reviewCount: json['review_count'] as int? ?? 0,
        setCount: json['set_count'] as int? ?? 0,
        imageCount: json['image_count'] as int? ?? 0,
        pendingBookingCount: json['pending_booking_count'] as int? ?? 0,
      );
}

/// Ảnh studio phía chủ studio (có id để đặt ảnh bìa / xoá).
class OwnerStudioImage {
  final String id;
  final String url; // địa chỉ đầy đủ
  final bool isCover;

  OwnerStudioImage({required this.id, required this.url, required this.isCover});

  factory OwnerStudioImage.fromJson(Map<String, dynamic> json) => OwnerStudioImage(
        id: json['id'] as String,
        url: ApiConstants.mediaUrl(json['url'] as String) ?? '',
        isCover: json['is_cover'] as bool? ?? false,
      );
}

/// Chi tiết studio của chính chủ (GET /studios/mine/:id).
/// Bước 15a dùng phần thông tin + ảnh; set / gói / nhân sự / dịch vụ quản lý ở bước 15b
/// (tạm giữ số lượng để hiện tổng quan).
class OwnerStudioDetail {
  final String id;
  final String name;
  final String address;
  final String district;
  final String phone;
  final String? description;
  final String status;
  final String? rejectReason;
  final String openTime;
  final String closeTime;
  final String eveningStartTime;
  final int eveningSurchargePct;
  final int weekendSurchargePct;
  final List<OwnerStudioImage> images;
  final int setCount;
  final int bookableSetCount; // set đang hiện và có ít nhất 1 gói đang bán
  final int staffCount;
  final int addonCount;

  OwnerStudioDetail({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.phone,
    this.description,
    required this.status,
    this.rejectReason,
    required this.openTime,
    required this.closeTime,
    required this.eveningStartTime,
    required this.eveningSurchargePct,
    required this.weekendSurchargePct,
    required this.images,
    required this.setCount,
    required this.bookableSetCount,
    required this.staffCount,
    required this.addonCount,
  });

  bool get isOpen24h => openTime == '00:00' && closeTime == '24:00';

  /// Đủ điều kiện để admin duyệt (khớp kiểm tra ở backend): có bối cảnh đang bán gói.
  bool get readyForApproval => bookableSetCount > 0;

  factory OwnerStudioDetail.fromJson(Map<String, dynamic> json) {
    final sets = (json['sets'] as List? ?? const []).cast<Map<String, dynamic>>();
    final bookable = sets.where((s) {
      final active = s['is_active'] as bool? ?? true;
      final packages = (s['packages'] as List? ?? const []).cast<Map<String, dynamic>>();
      return active && packages.any((p) => p['is_active'] as bool? ?? true);
    }).length;

    return OwnerStudioDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      district: json['district'] as String,
      phone: json['phone'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String,
      rejectReason: json['reject_reason'] as String?,
      openTime: json['open_time'] as String? ?? '08:00',
      closeTime: json['close_time'] as String? ?? '22:00',
      eveningStartTime: json['evening_start_time'] as String? ?? '18:00',
      eveningSurchargePct: json['evening_surcharge_pct'] as int? ?? 0,
      weekendSurchargePct: json['weekend_surcharge_pct'] as int? ?? 0,
      images: (json['images'] as List? ?? const [])
          .map((e) => OwnerStudioImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      setCount: sets.length,
      bookableSetCount: bookable,
      staffCount: (json['staff'] as List? ?? const []).length,
      addonCount: (json['addons'] as List? ?? const []).length,
    );
  }
}

/// Dữ liệu form tạo / sửa studio -> body của POST /studios, PUT /studios/:id.
class StudioFormData {
  final String name;
  final String address;
  final String district;
  final String phone;
  final String description;
  final String openTime;
  final String closeTime;
  final String eveningStartTime;
  final int eveningSurchargePct;
  final int weekendSurchargePct;

  const StudioFormData({
    required this.name,
    required this.address,
    required this.district,
    required this.phone,
    required this.description,
    required this.openTime,
    required this.closeTime,
    required this.eveningStartTime,
    required this.eveningSurchargePct,
    required this.weekendSurchargePct,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'district': district,
        'phone': phone,
        'description': description,
        'open_time': openTime,
        'close_time': closeTime,
        'evening_start_time': eveningStartTime,
        'evening_surcharge_pct': eveningSurchargePct,
        'weekend_surcharge_pct': weekendSurchargePct,
      };
}
