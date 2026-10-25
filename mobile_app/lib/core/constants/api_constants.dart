class ApiConstants {
  // Địa chỉ IP LAN của máy tính đang chạy Backend NestJS.
  // Lấy bằng lệnh `ipconfig` (Windows) -> mục "IPv4 Address" của Wi-Fi.
  //
  // LƯU Ý QUAN TRỌNG: địa chỉ này có thể ĐỔI mỗi khi máy tính kết nối lại
  // WiFi (do router cấp IP động - DHCP). Nếu sau này Flutter app không gọi
  // được API dù Backend vẫn chạy, việc đầu tiên cần kiểm tra là IP này còn
  // đúng không.
  static const String baseUrl = 'http://192.168.5.111:3000/api/v1';
   /// Ảnh lưu trên máy chủ dạng "/uploads/avatars/abc.jpg" -> ghép thành địa chỉ đầy đủ
  /// theo đúng IP trong baseUrl. Link đầy đủ sẵn (ảnh Google) thì giữ nguyên.
  static String? mediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '${Uri.parse(baseUrl).origin}$path';
  }
}
