import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -100,
            child: _glowCircle(AppColors.accent, 320, 0.14),
          ),
          Positioned(
            top: -120, left: -100,
            child: _glowCircle(AppColors.accent, 320, 0.13), // Moon Pink
          ),
          Positioned(
            bottom: -140, right: -110,
            child: _glowCircle(AppColors.accentGradientEnd, 360, 0.14), // Dusty Mauve
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
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ),
      ),
    );
  }
}