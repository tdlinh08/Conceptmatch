/// Báo cáo thống kê (GET /stats/admin, GET /stats/owner).
class StatBucket {
  final String key;
  final String label; // "07/11" hoặc "T11/26"
  final int bookings;
  final double revenue;
  final int newUsers;

  StatBucket({
    required this.key,
    required this.label,
    required this.bookings,
    required this.revenue,
    required this.newUsers,
  });

  factory StatBucket.fromJson(Map<String, dynamic> j) => StatBucket(
        key: j['key'] as String,
        label: j['label'] as String,
        bookings: (j['bookings'] as num? ?? 0).toInt(),
        revenue: (j['revenue'] as num? ?? 0).toDouble(),
        newUsers: (j['new_users'] as num? ?? 0).toInt(),
      );
}

/// 1 dòng xếp hạng (studio / bối cảnh / concept / quận).
class RankRow {
  final String name;
  final String? subtitle;
  final int bookings;
  final double revenue;
  final double? rating;

  RankRow({required this.name, this.subtitle, required this.bookings, this.revenue = 0, this.rating});
}

class StatsReport {
  final String range; // 7d | 30d | 12m
  final List<StatBucket> series;
  final int bookings;
  final double revenue;
  final int completed;
  final double lostRate; // % đơn huỷ / từ chối / không đến
  final double avgOrderValue;
  final int? newUsers; // chỉ admin
  final double? avgRating; // chỉ chủ studio
  final int? reviewCount;
  final Map<String, int> statusCounts;
  final List<RankRow> topStudios; // admin
  final List<RankRow> topSets; // chủ studio
  final List<RankRow> topConcepts;
  final List<RankRow> topDistricts;

  StatsReport({
    required this.range,
    required this.series,
    required this.bookings,
    required this.revenue,
    required this.completed,
    required this.lostRate,
    required this.avgOrderValue,
    this.newUsers,
    this.avgRating,
    this.reviewCount,
    required this.statusCounts,
    required this.topStudios,
    required this.topSets,
    required this.topConcepts,
    required this.topDistricts,
  });

  static List<Map<String, dynamic>> _list(Object? v) =>
      (v as List? ?? const []).cast<Map<String, dynamic>>();

  factory StatsReport.fromJson(Map<String, dynamic> j) {
    final t = j['totals'] as Map<String, dynamic>? ?? const {};
    return StatsReport(
      range: j['range'] as String? ?? '30d',
      series: _list(j['series']).map(StatBucket.fromJson).toList(),
      bookings: (t['bookings'] as num? ?? 0).toInt(),
      revenue: (t['revenue'] as num? ?? 0).toDouble(),
      completed: (t['completed'] as num? ?? 0).toInt(),
      lostRate: (t['lost_rate'] as num? ?? 0).toDouble(),
      avgOrderValue: (t['avg_order_value'] as num? ?? 0).toDouble(),
      newUsers: (t['new_users'] as num?)?.toInt(),
      avgRating: (t['avg_rating'] as num?)?.toDouble(),
      reviewCount: (t['review_count'] as num?)?.toInt(),
      statusCounts: (j['status_counts'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      topStudios: _list(j['top_studios'])
          .map((e) => RankRow(
                name: e['name'] as String,
                subtitle: e['district'] as String?,
                bookings: (e['completed'] as num? ?? 0).toInt(),
                revenue: (e['revenue'] as num? ?? 0).toDouble(),
                rating: (e['avg_rating'] as num?)?.toDouble(),
              ))
          .toList(),
      topSets: _list(j['top_sets'])
          .map((e) => RankRow(
                name: e['name'] as String,
                subtitle: e['studio_name'] as String?,
                bookings: (e['bookings'] as num? ?? 0).toInt(),
                revenue: (e['revenue'] as num? ?? 0).toDouble(),
              ))
          .toList(),
      topConcepts: _list(j['top_concepts'])
          .map((e) => RankRow(name: e['name'] as String, bookings: (e['bookings'] as num).toInt()))
          .toList(),
      topDistricts: _list(j['top_districts'])
          .map((e) => RankRow(name: e['name'] as String, bookings: (e['bookings'] as num).toInt()))
          .toList(),
    );
  }
}
