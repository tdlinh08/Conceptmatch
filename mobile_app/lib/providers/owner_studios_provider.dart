import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/api_error.dart';
import '../models/owner_studio_model.dart';

/// Lỗi nghiệp vụ trả về cho màn hình (câu tiếng Việt đã sẵn để hiện).
class OwnerActionException implements Exception {
  final String message;
  OwnerActionException(this.message);
  @override
  String toString() => message;
}

/// Dữ liệu phía CHỦ STUDIO: danh sách studio của tôi, chi tiết, tạo/sửa, ảnh studio.
class OwnerStudiosProvider extends ChangeNotifier {
  final _api = ApiClient();

  List<OwnerStudioSummary> studios = [];
  bool isLoading = false;
  bool loaded = false; // đã tải ít nhất 1 lần (phân biệt "đang tải lần đầu" với "chưa có studio")
  String? errorMessage;

  /// Tổng đơn đang chờ xác nhận của mọi studio (hiện ở tab Lịch đặt / Cá nhân).
  int get pendingBookingCount => studios.fold(0, (sum, s) => sum + s.pendingBookingCount);
  int get activeCount => studios.where((s) => s.status == StudioStatus.active).length;

  Future<void> fetchMine() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await _api.dio.get('/studios/mine');
      studios = (res.data as List)
          .map((e) => OwnerStudioSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      loaded = true;
    } catch (e) {
      errorMessage = apiErrorMessage(e, fallback: 'Không tải được danh sách studio');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Ném [OwnerActionException] khi lỗi để màn hình hiện thông báo + nút thử lại.
  Future<OwnerStudioDetail> fetchDetail(String id) async {
    try {
      final res = await _api.dio.get('/studios/mine/$id');
      return OwnerStudioDetail.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: 'Không tải được thông tin studio'));
    }
  }

  /// Tạo studio (luôn ở trạng thái Chờ duyệt). Trả về id studio mới.
  Future<String> createStudio(StudioFormData form) async {
    try {
      final res = await _api.dio.post('/studios', data: form.toJson());
      await fetchMine();
      return (res.data as Map<String, dynamic>)['id'] as String;
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: 'Không tạo được studio'));
    }
  }

  /// Sửa studio. Studio đang "Bị từ chối" -> backend tự chuyển về "Chờ duyệt".
  Future<void> updateStudio(String id, StudioFormData form) async {
    try {
      await _api.dio.put('/studios/$id', data: form.toJson());
      await fetchMine();
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: 'Không lưu được thay đổi'));
    }
  }

  // ---- Ảnh studio ----

  /// Tải nhiều ảnh (tối đa 10 / lần). Studio chưa có ảnh bìa -> ảnh đầu tiên thành ảnh bìa.
  Future<void> uploadImages(String studioId, List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      final form = FormData();
      for (final p in paths) {
        form.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(p, contentType: DioMediaType('image', _subtype(p))),
        ));
      }
      await _api.dio.post(
        '/studios/$studioId/images',
        data: form,
        options: Options(sendTimeout: const Duration(seconds: 60)),
      );
      await fetchMine(); // ảnh bìa / số ảnh trên thẻ đổi theo
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: 'Không tải được ảnh lên'));
    }
  }

  Future<void> setCover(String studioId, String imageId) async {
    try {
      await _api.dio.patch('/studios/$studioId/images/$imageId/cover');
      await fetchMine();
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: 'Không đổi được ảnh bìa'));
    }
  }

  Future<void> deleteImage(String studioId, String imageId) async {
    try {
      await _api.dio.delete('/studios/$studioId/images/$imageId');
      await fetchMine();
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: 'Không xoá được ảnh'));
    }
  }

  static String _subtype(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }

  /// Đăng xuất -> xoá dữ liệu của tài khoản cũ.
  void reset() {
    studios = [];
    isLoading = false;
    loaded = false;
    errorMessage = null;
    notifyListeners();
  }
}
