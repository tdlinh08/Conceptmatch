import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Lớp bản đồ nền OpenStreetMap (miễn phí, không cần API key).
/// userAgentPackageName: định danh app theo chính sách sử dụng tile của OSM.
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.mobile_app',
      maxZoom: 19,
    );

/// Ghi nguồn bản đồ (bắt buộc theo giấy phép ODbL của OpenStreetMap).
Widget osmAttribution() => const SimpleAttributionWidget(
      source: Text('© OpenStreetMap contributors'),
    );
