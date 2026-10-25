import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/studio_model.dart';
import '../../../providers/favorites_provider.dart';

/// Thẻ studio dạng ẢNH LỚN: ảnh tràn thẻ, tên + quận + điểm nằm trên lớp
/// gradient tối ở đáy ảnh (chữ sáng trên nền tối luôn đọc được, dù ảnh sáng hay tối).
class PhotoStudioCard extends StatelessWidget {
  final StudioModel studio;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const PhotoStudioCard({
    super.key,
    required this.studio,
    this.onTap,
    this.width = 240,
    this.height = 220,
  });

  static const Color _textOnImageSoft = Color(0xFFD9CDDD); // chữ phụ trên ảnh

  @override
  Widget build(BuildContext context) {
    final isFavorited = context.watch<FavoritesProvider>().isFavorited(studio.id);
    final isCompact = width < 200;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CoverImage(url: studio.coverImage),

            // Lớp gradient tối ở nửa dưới ảnh để chữ trắng luôn đọc được.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.42, 1.0],
                  colors: [Color(0x00161018), Color(0xEB161018)],
                ),
              ),
            ),

            // Tên, quận, điểm đánh giá.
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    studio.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textOnImage,
                      fontSize: isCompact ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: _textOnImageSoft),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          studio.district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _textOnImageSoft, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.star_rounded, size: 16, color: AppColors.ratingGoldOnImage),
                      const SizedBox(width: 2),
                      Text(
                        _ratingLabel(studio.avgRating),
                        style: const TextStyle(
                          color: AppColors.textOnImage,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Lớp bắt chạm phủ toàn thẻ (đặt SAU ảnh để hiệu ứng gợn sóng hiện lên trên ảnh).
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),

            // Nút yêu thích — đặt cuối cùng để nằm trên lớp bắt chạm.
            Positioned(
              top: 10,
              right: 10,
              child: _FavoriteButton(studio: studio, isFavorited: isFavorited),
            ),
          ],
        ),
      ),
    );
  }

  /// Studio chưa có đánh giá thì hiện "Mới" thay vì "0,0".
  static String _ratingLabel(double rating) {
    if (rating <= 0) return 'Mới';
    return rating.toStringAsFixed(1).replaceAll('.', ',');
  }
}

class _CoverImage extends StatelessWidget {
  final String? url;

  const _CoverImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const _ImagePlaceholder();

    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _ImagePlaceholder(),
      errorBuilder: (context, error, stackTrace) => const _ImagePlaceholder(),
    );
  }
}

/// Ảnh chờ: gradient tím nhạt → tím trầm, để khi chưa có ảnh thật thẻ vẫn đẹp.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE6CFD9), Color(0xFF8E7590)],
        ),
      ),
      child: Align(
        alignment: Alignment(0, -0.35),
        child: Icon(Icons.photo_camera_outlined, size: 30, color: Color(0xB3FFFFFF)),
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
    return Semantics(
      button: true,
      label: isFavorited ? 'Bỏ lưu studio' : 'Lưu studio',
      excludeSemantics: true,
      child: Material(
        // Đã lưu: khối Night Plum đặc. Chưa lưu: nền đen mờ trên ảnh.
        color: isFavorited ? AppColors.primary : Colors.black.withValues(alpha: 0.32),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.read<FavoritesProvider>().toggleFavorite(studio),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}