import 'package:url_launcher/url_launcher.dart';

/// Mở Google Maps (app nếu có, không thì trình duyệt) để chỉ đường tới studio.
/// Studio đã ghim vị trí -> chỉ đường tới đúng toạ độ; chưa ghim -> tìm theo địa chỉ.
/// Trả về false nếu không mở được.
Future<bool> openDirections({double? lat, double? lng, required String address}) async {
  final uri = lat != null && lng != null
      ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')
      : Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': address});
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
