class StudioModel {
  final String id;
  final String name;
  final String district;
  final double avgRating;
  final String? coverImage;

  /// Giá thuê thấp nhất (VNĐ/giờ) trong bảng giá của studio.
  /// null khi studio chưa khai báo bảng giá -> thẻ ẩn dòng giá.
  final double? minPrice;

  StudioModel({
    required this.id,
    required this.name,
    required this.district,
    required this.avgRating,
    this.coverImage,
    this.minPrice,
  });

  factory StudioModel.fromJson(Map<String, dynamic> json) {
    return StudioModel(
      id: json['id'] as String,
      name: json['name'] as String,
      district: json['district'] as String,
      avgRating: (json['avg_rating'] as num).toDouble(),
      coverImage: json['cover_image'] as String?,
      minPrice: (json['min_price'] as num?)?.toDouble(),
    );
  }
}