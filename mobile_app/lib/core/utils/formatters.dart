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

  /// "Thứ 7, 14/11/2026" (giờ máy).
  static String dateLabel(DateTime d) {
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    return '${weekdays[d.weekday - 1]}, ${_two(d.day)}/${_two(d.month)}/${d.year}';
  }

  /// 0.35 -> "350 m", 2.4 -> "2,4 km".
  static String km(double km) {
    if (km < 1) return '${(km * 1000 / 10).round() * 10} m';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// "09:30"
  static String hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

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
