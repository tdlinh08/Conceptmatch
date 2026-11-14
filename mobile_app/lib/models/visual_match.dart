import '../core/constants/api_constants.dart';

/// 1 bối cảnh AI tìm được (POST /ai/visual-search).
class VisualMatch {
  final String setId;
  final String setName;
  final String? styleTag;
  final String studioId;
  final String studioName;
  final String district;
  final double avgRating;
  final int reviewCount;
  final double? minPrice;
  final int? minPriceMinutes;
  final String imageUrl; // ảnh của bối cảnh giống ảnh tìm kiếm nhất (đại diện hoặc album)
  final double similarity; // cosine CLIP, 0..1

  VisualMatch({
    required this.setId,
    required this.setName,
    this.styleTag,
    required this.studioId,
    required this.studioName,
    required this.district,
    required this.avgRating,
    required this.reviewCount,
    this.minPrice,
    this.minPriceMinutes,
    required this.imageUrl,
    required this.similarity,
  });

  int get percent => (similarity * 100).round().clamp(0, 100).toInt();

  /// Mức giống (ngưỡng ước lượng theo thực nghiệm với CLIP ảnh–ảnh).
  String get level => similarity >= 0.85
      ? 'Rất giống'
      : similarity >= 0.75
          ? 'Khá giống'
          : 'Gợi ý';

  factory VisualMatch.fromJson(Map<String, dynamic> j) => VisualMatch(
        setId: j['set_id'] as String,
        setName: j['set_name'] as String,
        styleTag: j['style_tag'] as String?,
        studioId: j['studio_id'] as String,
        studioName: j['studio_name'] as String,
        district: j['district'] as String? ?? '',
        avgRating: (j['avg_rating'] as num? ?? 0).toDouble(),
        reviewCount: (j['review_count'] as num? ?? 0).toInt(),
        minPrice: (j['min_price'] as num?)?.toDouble(),
        minPriceMinutes: (j['min_price_minutes'] as num?)?.toInt(),
        imageUrl: ApiConstants.mediaUrl((j['matched_image_url'] ?? j['avatar_url']) as String?) ?? '',
        similarity: (j['similarity'] as num? ?? 0).toDouble(),
      );
}
