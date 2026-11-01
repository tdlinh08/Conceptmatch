/// Một thông báo trong app (GET /notifications).
class AppNotification {
  final String id;
  final String type; // booking_new | booking_confirmed | booking_rejected | booking_cancelled | booking_completed | review_new | studio_approved | studio_rejected
  final String title;
  final String body;
  final String? refId; // id đơn (booking_*, review_new) hoặc id studio (studio_*)
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.refId,
    required this.isRead,
    required this.createdAt,
  });

  /// Thông báo gắn với 1 đơn đặt lịch -> bấm vào mở "Chi tiết lịch hẹn".
  bool get opensBooking => refId != null && (type.startsWith('booking_') || type == 'review_new');

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        refId: refId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      refId: json['ref_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
