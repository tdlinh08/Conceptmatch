import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';

/// Ảnh tròn của người / studio trong chat; không có ảnh (hoặc ảnh lỗi) thì hiện chữ cái đầu.
class ChatAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;

  const ChatAvatar({super.key, required this.name, this.url, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final src = ApiConstants.mediaUrl(url);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.surfacePink, shape: BoxShape.circle),
      child: Text(
        _initial(name),
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: AppColors.accentText,
        ),
      ),
    );
    if (src == null) return fallback;
    return ClipOval(
      child: Image.network(
        src,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  static String _initial(String name) {
    final t = name.trim();
    return t.isEmpty ? '?' : t.characters.first.toUpperCase();
  }
}

/// "14:05" (hôm nay), "Hôm qua", "02/11" (cũ hơn).
String chatListTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final now = DateTime.now();
  if (DateUtils.isSameDay(now, t)) return '${two(t.hour)}:${two(t.minute)}';
  if (DateUtils.isSameDay(now.subtract(const Duration(days: 1)), t)) return 'Hôm qua';
  return '${two(t.day)}/${two(t.month)}';
}
