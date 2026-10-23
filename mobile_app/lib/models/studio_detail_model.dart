class StudioImageModel {
  final String url;
  final bool isCover;

  StudioImageModel({required this.url, required this.isCover});

  factory StudioImageModel.fromJson(Map<String, dynamic> json) {
    return StudioImageModel(
      url: json['url'] as String,
      isCover: json['is_cover'] as bool? ?? false,
    );
  }
}

class StudioSetModel {
  final String id;
  final String name;
  final String? description;
  final String? styleTag;
  final int capacity;
  final String avatarUrl;

  StudioSetModel({
    required this.id,
    required this.name,
    this.description,
    this.styleTag,
    required this.capacity,
    required this.avatarUrl,
  });

  factory StudioSetModel.fromJson(Map<String, dynamic> json) {
    return StudioSetModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      styleTag: json['style_tag'] as String?,
      capacity: json['capacity'] as int,
      avatarUrl: json['avatar_url'] as String,
    );
  }
}

class PricingRuleModel {
  final String slotType;
  final String dayType;
  final double pricePerHour;

  PricingRuleModel({
    required this.slotType,
    required this.dayType,
    required this.pricePerHour,
  });

  factory PricingRuleModel.fromJson(Map<String, dynamic> json) {
    return PricingRuleModel(
      slotType: json['slot_type'] as String,
      dayType: json['day_type'] as String,
      // price_per_hour trả về dạng chuỗi (kiểu Decimal của Prisma) -> parse thủ công
      pricePerHour: double.parse(json['price_per_hour'].toString()),
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
  final List<PricingRuleModel> pricingRules;

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
    required this.pricingRules,
  });

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
      pricingRules: (json['pricing_rules'] as List)
          .map((e) => PricingRuleModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
