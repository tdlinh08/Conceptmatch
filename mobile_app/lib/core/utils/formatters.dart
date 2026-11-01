/// Các hàm định dạng hiển thị dùng chung toàn app.
class Formatters {
  Formatters._();

  /// 250000 -> "250.000đ" (dấu chấm ngăn cách hàng nghìn theo kiểu Việt Nam).
  static String vnd(num amount) {
    final digits = amount.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    final sign = amount < 0 ? '-' : '';
    return '$sign${buffer.toString()}đ';
  }

  /// Thời lượng gói: 60 -> "1 giờ", 90 -> "1 giờ 30 phút", 30 -> "30 phút".
  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m phút';
    if (m == 0) return '$h giờ';
    return '$h giờ $m phút';
  }

  /// Số tiền trong JSON: kiểu Decimal của Prisma trả về dạng CHUỖI ("350000"),
  /// còn các trường đã đổi ở backend trả về dạng số -> chấp nhận cả hai.
  static double money(Object? value) =>
      value is num ? value.toDouble() : double.parse(value.toString());

  static double? moneyOrNull(Object? value) => value == null ? null : money(value);
}
