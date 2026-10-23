class StudioModel {
  final String id;
  final String name;
  final String district;
  final double avgRating;
  final String? coverImage;

  StudioModel({
    required this.id,
    required this.name,
    required this.district,
    required this.avgRating,
    this.coverImage,
  });

  factory StudioModel.fromJson(Map<String, dynamic> json) {
    return StudioModel(
      id: json['id'] as String,
      name: json['name'] as String,
      district: json['district'] as String,
      avgRating: (json['avg_rating'] as num).toDouble(),
      coverImage: json['cover_image'] as String?,
    );
  }
}
