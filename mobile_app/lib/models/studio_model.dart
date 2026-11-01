import '../core/constants/api_constants.dart';

class StudioModel {
  final String id;
  final String name;
  final String district;
  final double avgRating;
  final String? coverImage; // đã ghép thành địa chỉ đầy đủ (xem ApiConstants.mediaUrl)

  /// Giá của gói thuê RẺ NHẤT đang bán (VNĐ) và thời lượng của gói đó.
  /// null khi studio chưa có gói nào -> thẻ ẩn dòng giá.
  final double? minPrice;
  final int? minPriceMinutes;

  StudioModel({
    required this.id,
    required this.name,
    required this.district,
    required this.avgRating,
    this.coverImage,
    this.minPrice,
    this.minPriceMinutes,
  });

  factory StudioModel.fromJson(Map<String, dynamic> json) {
    return StudioModel(
      id: json['id'] as String,
      name: json['name'] as String,
      district: json['district'] as String,
      avgRating: (json['avg_rating'] as num).toDouble(),
      coverImage: ApiConstants.mediaUrl(json['cover_image'] as String?),
      minPrice: (json['min_price'] as num?)?.toDouble(),
      minPriceMinutes: json['min_price_minutes'] as int?,
    );
  }
}
