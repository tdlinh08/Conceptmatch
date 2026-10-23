class ReviewModel {
  final String id;
  final int stars;
  final String? comment;
  final DateTime createdAt;
  final String userName;
  final String? userAvatar;

  ReviewModel({
    required this.id,
    required this.stars,
    this.comment,
    required this.createdAt,
    required this.userName,
    this.userAvatar,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return ReviewModel(
      id: json['id'] as String,
      stars: json['stars'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: user['full_name'] as String,
      userAvatar: user['avatar_url'] as String?,
    );
  }
}
