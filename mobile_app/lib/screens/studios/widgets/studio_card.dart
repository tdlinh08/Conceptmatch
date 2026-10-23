import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/studio_model.dart';
import '../../../providers/favorites_provider.dart';

class StudioCard extends StatelessWidget {
  final StudioModel studio;
  final VoidCallback? onTap;

  const StudioCard({super.key, required this.studio, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isFavorited = context.watch<FavoritesProvider>().isFavorited(studio.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Stack(
              children: [
                _buildCoverImage(),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _FavoriteButton(studio: studio, isFavorited: isFavorited),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studio.name,
                      style: const TextStyle(
                        color: AppColors.neutralTitle, // ĐỔI: trước là AppColors.textPrimary
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.neutralFaint), // ĐỔI: trước là AppColors.textSecondary
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            studio.district,
                            style: const TextStyle(color: AppColors.neutralBody, fontSize: 13), // ĐỔI: trước là AppColors.textSecondary
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: AppColors.ratingGold),
                        const SizedBox(width: 4),
                        Text(
                          studio.avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.neutralTitle, // ĐỔI: trước là AppColors.textPrimary
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Đổi sang Soft Peach — tương phản ấm/lạnh rõ rệt
                        // với nền thẻ xanh, thay vì cùng tông dễ bị chìm.
                        const Icon(Icons.star, size: 16, color: AppColors.ratingGold),
                        const SizedBox(width: 4),
                        Text(
                          studio.avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.neutralTitle, 
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    const size = 96.0;

    if (studio.coverImage == null || studio.coverImage!.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: AppColors.surfaceVariant,
        child: const Icon(Icons.photo_camera, color: AppColors.textSecondary),
      );
    }

    return Image.network(
      studio.coverImage!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: size,
          height: size,
          color: AppColors.surfaceVariant,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: AppColors.surfaceVariant,
        child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final StudioModel studio;
  final bool isFavorited;

  const _FavoriteButton({required this.studio, required this.isFavorited});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<FavoritesProvider>().toggleFavorite(studio),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          // Đã yêu thích: nền đặc màu Moon Pink -> nổi bật rõ rệt, dễ phân biệt.
          // Chưa yêu thích: nền đen mờ như cũ.
          color: isFavorited ? AppColors.accent : Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFavorited ? Icons.favorite : Icons.favorite_border,
          // Đã yêu thích: icon tối màu (Night Plum) nổi rõ trên nền hồng sáng.
          // Chưa yêu thích: icon trắng, nổi trên nền đen mờ.
          color: isFavorited ? AppColors.onAccent : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}