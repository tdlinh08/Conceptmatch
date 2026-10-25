import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Nền chung của toàn app: trắng ngà + 2 quầng sáng rất nhẹ
/// (Moon Pink ở góc trên phải, Dusty Mauve ở góc dưới trái).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -120,
            child: _glowCircle(AppColors.moonPink, 340, 0.55),
          ),
          Positioned(
            bottom: -160,
            left: -130,
            child: _glowCircle(AppColors.dustyMauve, 360, 0.12),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(Color color, double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}