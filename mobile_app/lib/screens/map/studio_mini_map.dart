import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import 'map_tiles.dart';

/// Bản đồ nhỏ CHỈ ĐỂ XEM (không kéo/phóng) với 1 mũi ghim ở vị trí studio.
class StudioMiniMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double height;
  final VoidCallback? onTap;

  const StudioMiniMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 160,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                osmTileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter, // đầu nhọn của ghim chạm đúng điểm
                      child: const Icon(Icons.location_on, size: 40, color: AppColors.statusError),
                    ),
                  ],
                ),
                osmAttribution(),
              ],
            ),
            // Lớp bắt chạm phủ trên bản đồ (bản đồ không nhận thao tác)
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onTap),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
