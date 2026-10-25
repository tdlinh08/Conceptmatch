import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bảng màu ConceptMatch — BẢN SÁNG (chốt 25/10/2026).
///
/// Tỉ lệ tương phản ghi trong comment là đo theo WCAG trên nền [background].
/// Chuẩn tối thiểu cho chữ thường là 4.5 : 1.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // 1. MÀU THƯƠNG HIỆU (giữ nguyên 3 màu gốc)
  // ---------------------------------------------------------------------------
  static const Color moonPink = Color(0xFFF1D4D9); // chỉ dùng làm nền nhạt / gradient, KHÔNG làm chữ
  static const Color dustyMauve = Color(0xFFB58FA9); // gradient nút AI, thanh tiến độ
  static const Color nightPlum = Color(0xFF514254); // nút chính, mục đang chọn

  // ---------------------------------------------------------------------------
  // 2. NỀN VÀ BỀ MẶT
  // ---------------------------------------------------------------------------
  static const Color background = Color(0xFFFBF7F8); // nền toàn app (trắng ngà ấm)
  static const Color surface = Color(0xFFFFFFFF); // thẻ, ô nhập, thanh điều hướng
  static const Color surfaceMuted = Color(0xFFEFE6EA); // track thanh tiến độ, ảnh chờ tải
  static const Color surfacePink = Color(0xFFF6E6EA); // thẻ AI, nhãn nền hồng nhạt

  /// Viền thẻ. Thẻ trắng trên nền trắng ngà chỉ chênh 1.06 : 1,
  /// nên thẻ BẮT BUỘC có viền này (hoặc bóng nhẹ) để không bị mất.
  static const Color outline = Color(0x1F514254); // Night Plum, alpha 12%
  static const Color outlineStrong = Color(0x2E514254); // Night Plum, alpha 18% — chip chưa chọn

  // ---------------------------------------------------------------------------
  // 3. CHỮ
  // ---------------------------------------------------------------------------
  static const Color textTitle = Color(0xFF2A1F2D); // tiêu đề, tên studio, giá — 14.8 : 1
  static const Color textBody = Color(0xFF6E5D72); // mô tả, địa chỉ — 5.7 : 1
  static const Color textFaint = Color(0xFF776780); // nhãn nhỏ, gợi ý — 4.9 : 1
  static const Color textOnImage = Color(0xFFF7F2F6); // chữ đặt trên ảnh (có lớp gradient tối)

  // ---------------------------------------------------------------------------
  // 4. ĐIỂM NHẤN
  // ---------------------------------------------------------------------------
  static const Color primary = nightPlum; // nền nút chính / chip đang chọn
  static const Color onPrimary = Color(0xFFFFFFFF); // chữ trên nút chính — 9.3 : 1
  static const Color accentText = Color(0xFF9A4F71); // chữ nhấn: eyebrow, link, mục nav đang chọn — 5.3 : 1

  // ---------------------------------------------------------------------------
  // 5. TRẠNG THÁI (bản sáng phải đậm hơn bản tối mới đọc được trên nền trắng)
  // ---------------------------------------------------------------------------
  static const Color statusSuccess = Color(0xFF2F7D45); // 5.1 : 1
  static const Color statusError = Color(0xFFA94444); // 5.8 : 1
  static const Color statusWarning = Color(0xFF8A5D0E); // chữ "giờ vàng", cảnh báo — 5.8 : 1
  static const Color ratingGold = Color(0xFFB57D10); // sao trên nền sáng
  static const Color ratingGoldOnImage = Color(0xFFFFC857); // sao trên ảnh tối

  // ---------------------------------------------------------------------------
  // 6. TÊN CŨ — giữ tạm để các màn chưa làm lại vẫn biên dịch và hiển thị
  //    đúng tông sáng. Khi làm lại từng màn, đổi sang tên mới ở trên.
  //    Làm xong tất cả các màn thì xoá cả khối này.
  // ---------------------------------------------------------------------------
  static const Color cardBase = surface;
  static const Color surfaceVariant = surfaceMuted;
  static const Color surfaceElevated = surface;
  static const Color border = nightPlum; // code cũ luôn dùng kèm độ mờ (0.3–0.6)
  static const Color textPrimary = textTitle;
  static const Color textSecondary = textBody;
  static const Color textMuted = textFaint;
  static const Color navUnselected = textFaint;
  static const Color neutralTitle = textTitle;
  static const Color neutralBody = textBody;
  static const Color neutralFaint = textFaint;
  static const Color accent = primary; // code cũ dùng accent cho cả nền nút lẫn chữ nhấn
  static const Color onAccent = onPrimary;
  static const Color accentGradientStart = moonPink;
  static const Color accentGradientEnd = dustyMauve;
  static const Color accentPeach = surfacePink;
  static const Color accentMint = dustyMauve;
  static const Color iceGlow = moonPink;
  static const Color error = statusError;
  static const Color success = statusSuccess;
}

class AppTheme {
  AppTheme._();

  /// Thanh trạng thái Android/iOS: icon TỐI vì nền app sáng.
  static const SystemUiOverlayStyle systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.beVietnamProTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textTitle,
      displayColor: AppColors.textTitle,
    );

    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.accentText,
      onSecondary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textTitle,
      onSurfaceVariant: AppColors.textBody,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outline: AppColors.outlineStrong,
      outlineVariant: AppColors.outline,
      error: AppColors.statusError,
      onError: AppColors.onPrimary,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent, // để AppBackground hiện qua
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.textTitle),
      dividerColor: AppColors.outline,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textTitle,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: GoogleFonts.beVietnamPro(
          color: AppColors.textTitle,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.textFaint,
          elevation: 0,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: const StadiumBorder(), // nút dạng viên thuốc như bản thiết kế
          textStyle: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textTitle,
          side: const BorderSide(color: AppColors.outlineStrong),
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentText,
          textStyle: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.surfaceMuted,
        checkmarkColor: AppColors.onPrimary,
        labelStyle: GoogleFonts.beVietnamPro(
          color: AppColors.textBody,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: GoogleFonts.beVietnamPro(
          color: AppColors.onPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: AppColors.outlineStrong),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: GoogleFonts.beVietnamPro(color: AppColors.textFaint, fontSize: 14),
        labelStyle: GoogleFonts.beVietnamPro(color: AppColors.textBody, fontSize: 14),
        prefixIconColor: AppColors.textFaint,
        suffixIconColor: AppColors.textFaint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.statusError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.statusError, width: 1.5),
        ),
      ),

      // Thanh điều hướng cũ (BottomNavigationBar) — sẽ thay bằng thanh nổi ở bước sau.
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accentText,
        unselectedItemColor: AppColors.textFaint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textTitle,
        contentTextStyle: GoogleFonts.beVietnamPro(color: AppColors.onPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceMuted,
      ),
    );
  }
}