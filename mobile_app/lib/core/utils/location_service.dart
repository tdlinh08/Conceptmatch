import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Lỗi lấy vị trí, kèm câu tiếng Việt để hiện cho người dùng.
class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}

/// Lấy vị trí hiện tại của điện thoại (xin quyền nếu cần).
class LocationService {
  LocationService._();

  /// Trung tâm Hà Nội (Hồ Gươm) — điểm mặc định khi chưa có vị trí.
  static const hanoi = LatLng(21.0285, 105.8542);

  static Future<LatLng> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Định vị (GPS) đang tắt. Bật Vị trí trên điện thoại rồi thử lại.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException('Bạn chưa cho phép ứng dụng dùng vị trí.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Quyền vị trí đã bị chặn. Vào Cài đặt > Ứng dụng > ConceptMatch > Quyền để bật lại.',
      );
    }

    final last = await Geolocator.getLastKnownPosition();
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // đủ cho "gần tôi", nhanh và ít tốn pin
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // Trong nhà khó bắt GPS -> dùng vị trí gần nhất máy còn nhớ
      if (last != null) return LatLng(last.latitude, last.longitude);
      throw LocationException('Không lấy được vị trí. Thử lại ở nơi thoáng hoặc bật Wi-Fi.');
    }
  }
}
