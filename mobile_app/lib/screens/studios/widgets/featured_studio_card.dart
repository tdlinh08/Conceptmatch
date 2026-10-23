import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/studio_model.dart';
import '../../../providers/favorites_provider.dart';

class FeaturedStudioCard extends StatelessWidget {
  final StudioModel studio;
  final VoidCallback? onTap;

  const FeaturedStudioCard({super.key, required this.studio, this.onTap});

  static const double _width = 160;
  static const double _imageHeight = 100;
  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    final isFavorited = context.watch<FavoritesProvider>().isFavorited(studio.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _width,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBase,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildImage(),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => context.read<FavoritesProvider>().toggleFavorite(studio),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        // Đã yêu thích: nền đặc Moon Pink. Chưa yêu thích: nền đen mờ
                        // (đổi hẳn từ nền trắng cũ — đó chính là nguyên nhân icon bị chìm mất).
                        color: isFavorited ? AppColors.accent : Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: isFavorited ? AppColors.onAccent : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studio.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.neutralTitle, // ĐỔI: trước là AppColors.textPrimary
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: AppColors.ratingGold),
                      const SizedBox(width: 2),
                      Text(
                        studio.avgRating.toStringAsFixed(1),
                        style: const TextStyle(color: AppColors.neutralBody, fontSize: 12), // ĐỔI: trước là AppColors.textSecondary
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          studio.district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.neutralBody, fontSize: 12), // ĐỔI: trước là AppColors.textSecondary
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (studio.coverImage == null || studio.coverImage!.isEmpty) {
      return Container(
        height: _imageHeight,
        width: double.infinity,
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(Icons.photo_camera, color: AppColors.textSecondary),
        ),
      );
    }

    return Image.network(
      studio.coverImage!,
      height: _imageHeight,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: _imageHeight,
          color: AppColors.surfaceVariant,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        height: _imageHeight,
        color: AppColors.surfaceVariant,
        child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
      ),
    );
  }
}
