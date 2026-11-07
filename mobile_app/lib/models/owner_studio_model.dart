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

/// Gói thuê phía chủ studio (gồm cả gói đang ẩn).
class OwnerPackage {
  final String id;
  final String name;
  final String? description;
  final int durationMinutes;
  final double price;
  final int includedPeople;
  final double extraPersonFee;
  final int maxPeople;
  final bool isActive;

  OwnerPackage({
    required this.id,
    required this.name,
    this.description,
    required this.durationMinutes,
    required this.price,
    required this.includedPeople,
    required this.extraPersonFee,
    required this.maxPeople,
    required this.isActive,
  });

  factory OwnerPackage.fromJson(Map<String, dynamic> json) => OwnerPackage(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        durationMinutes: json['duration_minutes'] as int,
        price: _money(json['price']),
        includedPeople: json['included_people'] as int,
        extraPersonFee: _money(json['extra_person_fee']),
        maxPeople: json['max_people'] as int,
        isActive: json['is_active'] as bool? ?? true,
      );
}

/// Ảnh trong album của bối cảnh.
class OwnerSetImage {
  final String id;
  final String url; // địa chỉ đầy đủ
  OwnerSetImage({required this.id, required this.url});
}

/// Bối cảnh (set) phía chủ studio (gồm cả set đang ẩn và gói đang ẩn).
class OwnerSet {
  final String id;
  final String name;
  final String? description;
  final String? styleTag;
  final int capacity;
  final String avatarUrl; // địa chỉ đầy đủ
  final String avatarPath; // đường dẫn gốc từ máy chủ (gửi lại khi sửa)
  final bool isActive;
  final List<OwnerSetImage> images;
  final List<OwnerPackage> packages;

  OwnerSet({
    required this.id,
    required this.name,
    this.description,
    this.styleTag,
    required this.capacity,
    required this.avatarUrl,
    required this.avatarPath,
    required this.isActive,
    required this.images,
    required this.packages,
  });

  List<OwnerPackage> get activePackages => packages.where((p) => p.isActive).toList();

  /// Khách đặt được: set đang hiện và có ít nhất 1 gói đang bán.
  bool get isBookable => isActive && activePackages.isNotEmpty;

  factory OwnerSet.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_url'] as String? ?? '';
    return OwnerSet(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      styleTag: json['style_tag'] as String?,
      capacity: json['capacity'] as int,
      avatarUrl: ApiConstants.mediaUrl(avatar) ?? '',
      avatarPath: avatar,
      isActive: json['is_active'] as bool? ?? true,
      images: (json['images'] as List? ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map((e) => OwnerSetImage(
                id: e['id'] as String,
                url: ApiConstants.mediaUrl(e['url'] as String) ?? '',
              ))
          .toList(),
      packages: (json['packages'] as List? ?? const [])
          .map((e) => OwnerPackage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Nhân sự: thợ ảnh / thợ trang điểm.
class OwnerStaff {
  final String id;
  final String fullName;
  final String role; // photographer | makeup
  final String? phone;
  final bool isActive;

  OwnerStaff({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    required this.isActive,
  });

  factory OwnerStaff.fromJson(Map<String, dynamic> json) => OwnerStaff(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        phone: json['phone'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}

/// Dịch vụ thêm (khách tự chọn khi đặt).
class OwnerAddon {
  final String id;
  final String role; // vai trò cần: photographer | makeup
  final String name;
  final String? description;
  final double price;
  final String unit; // per_booking | per_hour | per_person
  final bool isActive;

  OwnerAddon({
    required this.id,
    required this.role,
    required this.name,
    this.description,
    required this.price,
    required this.unit,
    required this.isActive,
  });

  factory OwnerAddon.fromJson(Map<String, dynamic> json) => OwnerAddon(
        id: json['id'] as String,
        role: json['role'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: _money(json['price']),
        unit: json['unit'] as String,
        isActive: json['is_active'] as bool? ?? true,
      );
}

/// Tiền trong JSON có thể là số hoặc chuỗi (Decimal của Prisma).
double _money(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.parse(v.toString()));

/// Chi tiết studio của chính chủ (GET /studios/mine/:id): thông tin, ảnh,
/// bối cảnh + gói (gồm cả mục đang ẩn), nhân sự, dịch vụ thêm.
class OwnerStudioDetail {
  final String id;
  final String name;
  final String address;
  final String district;
  final String phone;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? rejectReason;
  final String openTime;
  final String closeTime;
  final String eveningStartTime;
  final int eveningSurchargePct;
  final int weekendSurchargePct;
  final List<OwnerStudioImage> images;
  final List<OwnerSet> sets;
  final List<OwnerStaff> staff;
  final List<OwnerAddon> addons;

  OwnerStudioDetail({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.phone,
    this.description,
    this.latitude,
    this.longitude,
    required this.status,
    this.rejectReason,
    required this.openTime,
    required this.closeTime,
    required this.eveningStartTime,
    required this.eveningSurchargePct,
    required this.weekendSurchargePct,
    required this.images,
    required this.sets,
    required this.staff,
    required this.addons,
  });

  bool get isOpen24h => openTime == '00:00' && closeTime == '24:00';
  bool get hasLocation => latitude != null && longitude != null;

  /// Số phút mở cửa mỗi ngày — gói thuê không được dài hơn (khớp kiểm tra ở backend).
  int get openMinutes {
    int m(String t) => int.parse(t.split(':')[0]) * 60 + int.parse(t.split(':')[1]);
    return m(closeTime) - m(openTime);
  }

  int get setCount => sets.length;
  int get bookableSetCount => sets.where((s) => s.isBookable).length;
  int get staffCount => staff.where((s) => s.isActive).length;
  int get addonCount => addons.where((a) => a.isActive).length;
  int activeStaffOf(String role) => staff.where((s) => s.isActive && s.role == role).length;

  /// Đủ điều kiện để admin duyệt (khớp kiểm tra ở backend): có bối cảnh đang bán gói.
  bool get readyForApproval => bookableSetCount > 0;

  OwnerSet? setById(String id) {
    for (final s in sets) {
      if (s.id == id) return s;
    }
    return null;
  }

  factory OwnerStudioDetail.fromJson(Map<String, dynamic> json) {
    return OwnerStudioDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      district: json['district'] as String,
      phone: json['phone'] as String? ?? '',
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
      sets: (json['sets'] as List? ?? const [])
          .map((e) => OwnerSet.fromJson(e as Map<String, dynamic>))
          .toList(),
      staff: (json['staff'] as List? ?? const [])
          .map((e) => OwnerStaff.fromJson(e as Map<String, dynamic>))
          .toList(),
      addons: (json['addons'] as List? ?? const [])
          .map((e) => OwnerAddon.fromJson(e as Map<String, dynamic>))
          .toList(),
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
  final double? latitude; // null cả 2 = chưa ghim / xoá ghim
  final double? longitude;

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
    this.latitude,
    this.longitude,
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
        // Luôn gửi cả 2 (null = xoá ghim) — backend yêu cầu đi theo cặp
        'latitude': latitude,
        'longitude': longitude,
      };
}
