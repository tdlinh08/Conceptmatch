import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/review_model.dart';

/// Thẻ 1 đánh giá — dùng chung cho màn chi tiết studio và màn "Tất cả đánh giá".
class ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final name = review.userName.trim();
    final initial = name.isEmpty ? '?' : name.split(' ').last[0].toUpperCase();
    final d = review.createdAt.toLocal();
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final avatar = review.userAvatar;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfacePink,
                // Có ảnh đại diện -> hiện ảnh; ảnh lỗi/không có -> chữ cái đầu của tên
                foregroundImage: avatar != null ? NetworkImage(avatar) : null,
                onForegroundImageError: avatar != null ? (_, _) {} : null,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentText,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                    ),
                    Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                  ],
                ),
              ),
              Semantics(
                label: '${review.stars} trên 5 sao',
                excludeSemantics: true,
                child: Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: AppColors.ratingGold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!.trim(),
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
            ),
          ],
        ],
      ),
    );
  }
}
