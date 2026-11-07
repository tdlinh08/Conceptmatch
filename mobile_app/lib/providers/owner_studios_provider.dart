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

  // ===========================================================================
  // Bước 15b: bối cảnh (set) + album, gói thuê, nhân sự, dịch vụ thêm
  // ===========================================================================

  /// Gọi API, đổi lỗi thành [OwnerActionException] có câu tiếng Việt.
  Future<T> _call<T>(Future<T> Function() fn, String fallback) async {
    try {
      return await fn();
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: fallback));
    }
  }

  Future<MultipartFile> _file(String path) =>
      MultipartFile.fromFile(path, contentType: DioMediaType('image', _subtype(path)));

  /// Cảnh báo AI (vd dịch vụ AI chưa bật) -> màn hình hiện nhẹ, không phải lỗi.
  static List<String> _warnings(dynamic data) =>
      data is Map && data['ai_warnings'] is List
          ? (data['ai_warnings'] as List).map((e) => e.toString()).toList()
          : const [];

  /// Tải 1 ảnh lên (ảnh đại diện set) -> trả về đường dẫn để gửi trong avatar_url.
  Future<String> uploadMedia(String studioId, String path) => _call(() async {
        final res = await _api.dio.post(
          '/studios/$studioId/media',
          data: FormData.fromMap({'image': await _file(path)}),
          options: Options(sendTimeout: const Duration(seconds: 60)),
        );
        return (res.data as Map<String, dynamic>)['url'] as String;
      }, 'Không tải được ảnh lên');

  /// Tạo bối cảnh. Trả về cảnh báo AI (nếu có).
  Future<List<String>> createSet(String studioId, Map<String, dynamic> body) => _call(() async {
        final res = await _api.dio.post('/studios/$studioId/sets', data: body);
        await fetchMine();
        return _warnings(res.data);
      }, 'Không tạo được bối cảnh');

  /// Sửa / ẩn-hiện bối cảnh. Trả về cảnh báo AI (nếu có).
  Future<List<String>> updateSet(String studioId, String setId, Map<String, dynamic> body) =>
      _call(() async {
        final res = await _api.dio.put('/studios/$studioId/sets/$setId', data: body);
        await fetchMine();
        return _warnings(res.data);
      }, 'Không lưu được bối cảnh');

  /// Thêm ảnh vào album bối cảnh (tối đa 10 ảnh / bối cảnh).
  Future<void> addSetImages(String studioId, String setId, List<String> paths) => _call(() async {
        final form = FormData();
        for (final p in paths) {
          form.files.add(MapEntry('images', await _file(p)));
        }
        await _api.dio.post(
          '/studios/$studioId/sets/$setId/images',
          data: form,
          options: Options(sendTimeout: const Duration(seconds: 60)),
        );
      }, 'Không tải được ảnh lên');

  Future<void> deleteSetImage(String studioId, String setId, String imageId) => _call(
        () => _api.dio.delete('/studios/$studioId/sets/$setId/images/$imageId'),
        'Không xoá được ảnh',
      );

  Future<void> createPackage(String studioId, String setId, Map<String, dynamic> body) => _call(
        () => _api.dio.post('/studios/$studioId/sets/$setId/packages', data: body),
        'Không tạo được gói thuê',
      );

  Future<void> updatePackage(
    String studioId,
    String setId,
    String packageId,
    Map<String, dynamic> body,
  ) =>
      _call(
        () => _api.dio.put('/studios/$studioId/sets/$setId/packages/$packageId', data: body),
        'Không lưu được gói thuê',
      );

  Future<void> createStaff(String studioId, Map<String, dynamic> body) => _call(
        () => _api.dio.post('/studios/$studioId/staff', data: body),
        'Không thêm được nhân sự',
      );

  Future<void> updateStaff(String studioId, String staffId, Map<String, dynamic> body) => _call(
        () => _api.dio.put('/studios/$studioId/staff/$staffId', data: body),
        'Không lưu được nhân sự',
      );

  Future<void> createAddon(String studioId, Map<String, dynamic> body) => _call(
        () => _api.dio.post('/studios/$studioId/addons', data: body),
        'Không thêm được dịch vụ',
      );

  Future<void> updateAddon(String studioId, String addonId, Map<String, dynamic> body) => _call(
        () => _api.dio.put('/studios/$studioId/addons/$addonId', data: body),
        'Không lưu được dịch vụ',
      );

  /// Các concept đang có trên hệ thống -> gợi ý khi đặt concept cho bối cảnh.
  Future<List<String>> fetchStyleTags() async {
    try {
      final res = await _api.dio.get('/studios/style-tags');
      return (res.data as List).cast<String>();
    } catch (_) {
      return const [];
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
