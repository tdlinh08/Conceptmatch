import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bảng màu "Velvet & Cerulean" — QUYẾT ĐỊNH CUỐI CÙNG, không đổi nữa.
class AppColors {
  // Nền chính — Night Plum: tối, sang, làm nền cho toàn bộ app
  static const Color background = Color(0xFF514254);

  // Nền thẻ — vẫn là Night Plum, không thêm màu mới, chỉ khác nền chính nhờ
  // lớp phủ Dusty Mauve mờ áp ở từng widget (xem ghi chú _cardDecoration bên dưới)
  static const Color cardBase = Color(0xFF514254);
  static const Color surface = Color(0xFF514254);
  static const Color surfaceVariant = Color(0xFF514254); // dùng kèm overlay Dusty Mauve khi render

  // Viền & chữ phụ — Dusty Mauve
  static const Color border = Color(0xFFB58FA9);
  static const Color textSecondary = Color(0xFFB58FA9);
  static const Color navUnselected = Color(0xFFB58FA9);

  // Nhấn chính — Moon Pink: CTA, icon AI, trạng thái active
  static const Color accent = Color(0xFFF1D4D9);
  static const Color accentGradientStart = Color(0xFFF1D4D9);
  static const Color accentGradientEnd = Color(0xFFB58FA9); // gradient Pink -> Mauve cho hiệu ứng AI quét ảnh

  // Điểm nhấn phụ — giữ Moon Pink cho sao đánh giá để đồng bộ tông ấm
  static const Color accentPeach = Color(0xFFF1D4D9);
  static const Color accentMint = Color(0xFFB58FA9);
  static const Color iceGlow = Color(0xFFF1D4D9); // viền phát sáng quanh avatar

  // Chữ
  static const Color textPrimary = Color(0xFFF1D4D9); // Moon Pink — chữ chính trên nền tối
  static const Color error = Color(0xFFE8A0A8);
  static const Color success = Color(0xFFB58FA9);
  static const Color onAccent = Color(0xFF514254); // QUAN TRỌNG: chữ TỐI trên nút CTA màu sáng, khác các bản trước

  static Color get surfaceElevated =>
      Color.alphaBlend(border.withOpacity(0.5), background);
  static Color get textMuted => textPrimary.withOpacity(0.55);
  static const Color ratingGold = Color(0xFFFFC857);

  static const Color neutralTitle = Color(0xFFEDE6EC);    // tiêu đề thường (không phải heading nhấn)
  static const Color neutralBody = Color(0xFFBDAEC2);     // nội dung mô tả, text phụ
  static const Color neutralFaint = Color(0xFF8A7A90);    // caption, placeholder, disabled

  // Semantic — trạng thái, KHÔNG lấy từ bộ màu thương hiệu để tránh nhầm lẫn
  // (vd: không thể dùng Moon Pink cho cả "CTA" lẫn "đặt lịch thành công")
  static const Color statusSuccess = Color(0xFF8FCB9B);
  static const Color statusError = Color(0xFFE08A8A);
  static const Color statusWarning = Color(0xFFE8C275);
}


class AppTheme {
  static ThemeData get lightTheme {
  final baseTextTheme = GoogleFonts.montserratTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark, // QUAN TRỌNG: đổi từ light -> dark cho bảng màu này
    scaffoldBackgroundColor: Colors.transparent, // để AppBackground hiện qua
    fontFamily: GoogleFonts.montserrat().fontFamily,
    textTheme: baseTextTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      background: AppColors.background,
      surface: AppColors.surface,
      primary: AppColors.accent,
      error: AppColors.error,
    ),

    cardTheme: CardThemeData(
      color: AppColors.cardBase.withOpacity(1.0), // giữ nguyên
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border.withOpacity(0.35), width: 1), // viền Dusty Mauve làm thẻ nổi lên
      ),
      margin: EdgeInsets.zero,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.accent,
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      side: BorderSide(color: AppColors.border.withOpacity(0.4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent, // chữ Night Plum tối trên nền Moon Pink sáng
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border.withOpacity(0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceElevated,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
    ),

    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    dividerColor: AppColors.border.withOpacity(0.3),
  );
  }
}