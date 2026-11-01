// Kiểm thử đơn vị cho các hàm định dạng dùng chung (không cần máy chủ).
// Chạy: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/formatters.dart';

void main() {
  group('Formatters.vnd', () {
    test('ngăn cách hàng nghìn bằng dấu chấm', () {
      expect(Formatters.vnd(250000), '250.000đ');
      expect(Formatters.vnd(1250000), '1.250.000đ');
      expect(Formatters.vnd(0), '0đ');
      expect(Formatters.vnd(999), '999đ');
    });

    test('số âm và số lẻ được làm tròn', () {
      expect(Formatters.vnd(-50000), '-50.000đ');
      expect(Formatters.vnd(104999.6), '105.000đ');
    });
  });

  group('Formatters.duration', () {
    test('đổi phút sang giờ/phút', () {
      expect(Formatters.duration(30), '30 phút');
      expect(Formatters.duration(60), '1 giờ');
      expect(Formatters.duration(90), '1 giờ 30 phút');
      expect(Formatters.duration(240), '4 giờ');
    });
  });

  group('Formatters.money', () {
    test('nhận cả số lẫn chuỗi (Decimal của Prisma)', () {
      expect(Formatters.money(350000), 350000.0);
      expect(Formatters.money('350000'), 350000.0);
      expect(Formatters.money('105000.50'), 105000.5);
      expect(Formatters.moneyOrNull(null), isNull);
    });
  });
}
