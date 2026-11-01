import '../core/constants/api_constants.dart';

class StudioImageModel {
  final String url; // đã ghép thành địa chỉ đầy đủ
  final bool isCover;

  StudioImageModel({required this.url, required this.isCover});

  factory StudioImageModel.fromJson(Map<String, dynamic> json) {
    return StudioImageModel(
      url: ApiConstants.mediaUrl(json['url'] as String) ?? '',
      isCover: json['is_cover'] as bool? ?? false,
    );
  }
}

/// Gói thuê của một set (GET /studios/:id -> sets[].packages[]).
/// Giá thật (kèm phụ thu giờ tối / cuối tuần) do backend tính theo từng giờ bắt đầu.
class RentalPackageModel {
  final String id;
  final String name;
  final String? description;
  final int durationMinutes;
  final double price; // giá gói, đã gồm [includedPeople] người
  final int includedPeople;
  final double extraPersonFee; // mỗi người vượt [includedPeople]
  final int maxPeople;

  RentalPackageModel({
    required this.id,
    required this.name,
    this.description,
    required this.durationMinutes,
    required this.price,
    required this.includedPeople,
    required this.extraPersonFee,
    required this.maxPeople,
  });

  /// Giá theo số người, CHƯA gồm phụ thu giờ tối / cuối tuần (chỉ để hiển thị nhanh).
  double priceFor(int people) =>
      price + (people > includedPeople ? (people - includedPeople) * extraPersonFee : 0);

  factory RentalPackageModel.fromJson(Map<String, dynamic> json) {
    return RentalPackageModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      durationMinutes: json['duration_minutes'] as int,
      price: (json['price'] as num).toDouble(),
      includedPeople: json['included_people'] as int,
      extraPersonFee: (json['extra_person_fee'] as num).toDouble(),
      maxPeople: json['max_people'] as int,
    );
  }
}

/// Vai trò nhân sự: thợ ảnh / thợ trang điểm (khớp enum StaffRole ở backend).
class StaffRoles {
  StaffRoles._();
  static const photographer = 'photographer';
  static const makeup = 'makeup';

  static String label(String role) => role == makeup ? 'Trang điểm' : 'Thợ ảnh';
}

/// Dịch vụ thêm khách tự chọn khi đặt (GET /studios/:id -> addons[]).
/// Mỗi dịch vụ cần 1 người thuộc [role]; studio phân công người cụ thể khi xác nhận đơn.
class AddonServiceModel {
  final String id;
  final String role; // photographer | makeup
  final String name;
  final String? description;
  final double price;
  final String unit; // per_booking | per_hour | per_person

  AddonServiceModel({
    required this.id,
    required this.role,
    required this.name,
    this.description,
    required this.price,
    required this.unit,
  });

  /// "/giờ", "/người", "/lượt"
  String get unitLabel => switch (unit) {
        'per_hour' => '/giờ',
        'per_person' => '/người',
        _ => '/lượt',
      };

  /// Tiền dịch vụ ước tính cho gói [durationMinutes] và [people] người (backend tính lại khi đặt).
  double amountFor(int durationMinutes, int people) => switch (unit) {
        'per_hour' => ((price * durationMinutes / 60) / 1000).round() * 1000.0,
        'per_person' => price * people,
        _ => price,
      };

  factory AddonServiceModel.fromJson(Map<String, dynamic> json) {
    return AddonServiceModel(
      id: json['id'] as String,
      role: json['role'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }
}

class StudioSetModel {
  final String id;
  final String name;
  final String? description;
  final String? styleTag;
  final int capacity;
  final String avatarUrl; // đã ghép thành địa chỉ đầy đủ
  final List<RentalPackageModel> packages; // backend đã sắp theo giá tăng dần

  StudioSetModel({
    required this.id,
    required this.name,
    this.description,
    this.styleTag,
    required this.capacity,
    required this.avatarUrl,
    required this.packages,
  });

  /// Set chưa có gói nào thì chưa đặt được.
  bool get isBookable => packages.isNotEmpty;

  factory StudioSetModel.fromJson(Map<String, dynamic> json) {
    return StudioSetModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      styleTag: json['style_tag'] as String?,
      capacity: json['capacity'] as int,
      avatarUrl: ApiConstants.mediaUrl(json['avatar_url'] as String) ?? '',
      packages: ((json['packages'] as List?) ?? const [])
          .map((e) => RentalPackageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StudioDetailModel {
  final String id;
  final String name;
  final String address;
  final String district;
  final String? description;
  final String phone;
  final double avgRating;
  final int reviewCount;
  final List<StudioImageModel> images;
  final List<StudioSetModel> sets;

  // Giờ hoạt động + phụ thu (thay cho bảng giá 4 ô cũ)
  final String openTime; // "08:00"
  final String closeTime; // "22:00" ("24:00" = mở tới nửa đêm)
  final String eveningStartTime; // "18:00"
  final int eveningSurchargePct;
  final int weekendSurchargePct;

  // Dịch vụ thêm đang bán (backend đã ẩn dịch vụ của vai trò chưa có người) + số thợ
  final List<AddonServiceModel> addons;
  final int photographerCount;
  final int makeupCount;

  StudioDetailModel({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    this.description,
    required this.phone,
    required this.avgRating,
    required this.reviewCount,
    required this.images,
    required this.sets,
    required this.openTime,
    required this.closeTime,
    required this.eveningStartTime,
    required this.eveningSurchargePct,
    required this.weekendSurchargePct,
    required this.addons,
    required this.photographerCount,
    required this.makeupCount,
  });

  int staffCount(String role) => role == StaffRoles.makeup ? makeupCount : photographerCount;

  /// Gói rẻ nhất trong toàn studio (null nếu chưa có gói nào).
  RentalPackageModel? get cheapestPackage {
    RentalPackageModel? best;
    for (final set in sets) {
      for (final p in set.packages) {
        if (best == null || p.price < best.price) best = p;
      }
    }
    return best;
  }

  bool get isOpen24h => openTime == '00:00' && closeTime == '24:00';

  factory StudioDetailModel.fromJson(Map<String, dynamic> json) {
    return StudioDetailModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      district: json['district'] as String,
      description: json['description'] as String?,
      phone: json['phone'] as String,
      avgRating: (json['avg_rating'] as num).toDouble(),
      reviewCount: json['review_count'] as int,
      images: (json['images'] as List)
          .map((e) => StudioImageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      sets: (json['sets'] as List)
          .map((e) => StudioSetModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      openTime: json['open_time'] as String? ?? '08:00',
      closeTime: json['close_time'] as String? ?? '22:00',
      eveningStartTime: json['evening_start_time'] as String? ?? '18:00',
      eveningSurchargePct: json['evening_surcharge_pct'] as int? ?? 0,
      weekendSurchargePct: json['weekend_surcharge_pct'] as int? ?? 0,
      addons: ((json['addons'] as List?) ?? const [])
          .map((e) => AddonServiceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      photographerCount: (json['staff_counts'] as Map?)?['photographer'] as int? ?? 0,
      makeupCount: (json['staff_counts'] as Map?)?['makeup'] as int? ?? 0,
    );
  }
}
