import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/studio_model.dart';

class FavoritesProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<StudioModel> favoriteStudios = [];
  Set<String> favoriteIds = {};
  bool isLoading = false;
  String? errorMessage;

  bool isFavorited(String studioId) => favoriteIds.contains(studioId);

  Future<void> fetchFavorites() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/favorites');
      favoriteStudios = (response.data as List)
          .map((e) => StudioModel.fromJson(e as Map<String, dynamic>))
          .toList();
      favoriteIds = favoriteStudios.map((s) => s.id).toSet();
    } catch (e) {
      errorMessage = 'Không tải được danh sách yêu thích.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Cập nhật lạc quan (optimistic update): đổi trạng thái tim ngay lập tức
  /// trên UI, gọi API ở nền sau — nếu API lỗi thì hoàn tác lại trạng thái
  /// cũ. Giúp thao tác bấm tim có cảm giác tức thời, không phải chờ loading
  /// mỗi lần bấm (khác với các thao tác quan trọng như đặt lịch, nơi cần
  /// chờ xác nhận thật từ server trước khi cập nhật UI).
  Future<void> toggleFavorite(StudioModel studio) async {
    final wasFavorited = favoriteIds.contains(studio.id);

    if (wasFavorited) {
      favoriteIds.remove(studio.id);
      favoriteStudios.removeWhere((s) => s.id == studio.id);
    } else {
      favoriteIds.add(studio.id);
      favoriteStudios.insert(0, studio);
    }
    notifyListeners();

    try {
      if (wasFavorited) {
        await _apiClient.dio.delete('/studios/${studio.id}/favorite');
      } else {
        await _apiClient.dio.post('/studios/${studio.id}/favorite');
      }
    } catch (e) {
      // Hoàn tác nếu gọi API thất bại (vd: mất mạng giữa chừng)
      if (wasFavorited) {
        favoriteIds.add(studio.id);
        favoriteStudios.insert(0, studio);
      } else {
        favoriteIds.remove(studio.id);
        favoriteStudios.removeWhere((s) => s.id == studio.id);
      }
      notifyListeners();
    }
  }
}
