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
    return '${amount < 0 ? '-' : ''}${buffer}đ';
  }
}