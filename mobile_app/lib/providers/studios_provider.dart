import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/studio_model.dart';
import '../models/studio_detail_model.dart';
import '../models/review_model.dart';

class StudiosProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // ---- Danh sách đầy đủ (dùng cho màn "Tất cả Studio") ----
  List<StudioModel> studios = [];
  bool isLoading = false;
  String? errorMessage;

  int _page = 1;
  int _totalCount = 0;
  bool _hasMore = true;
  String _keyword = '';
  String? _styleTag;

  bool get hasMore => _hasMore;

  /// [reset] = true: tìm kiếm/lọc mới (xoá danh sách cũ).
  /// [reset] = false: tải thêm trang tiếp theo (cuộn tới đâu tải tới đó).
  Future<void> fetchStudios({
    String? keyword,
    String? styleTag,
    bool reset = true,
  }) async {
    if (reset) {
      _page = 1;
      studios = [];
      _hasMore = true;
      _keyword = keyword ?? '';
      _styleTag = styleTag;
    }

    if (!_hasMore || isLoading) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(
        '/studios',
        queryParameters: {
          if (_keyword.isNotEmpty) 'keyword': _keyword,
          if (_styleTag != null) 'style_tag': _styleTag,
          'page': _page,
          'limit': 10,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final items = data['data'] as List<dynamic>;
      _totalCount = data['total'] as int;

      final newStudios = items
          .map((e) => StudioModel.fromJson(e as Map<String, dynamic>))
          .toList();

      studios = [...studios, ...newStudios];
      _hasMore = studios.length < _totalCount;
      _page++;
    } catch (e) {
      errorMessage = 'Không tải được danh sách studio. Kiểm tra lại kết nối.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() => fetchStudios(reset: false);

  // ---- Dữ liệu cho màn Home (nổi bật / danh mục / gợi ý cá nhân hoá) ----

  List<StudioModel> featuredStudios = [];
  List<StudioModel> forYouStudios = [];
  List<String> styleTags = [];

  bool isLoadingFeatured = false;
  bool isLoadingForYou = false;
  bool isLoadingStyleTags = false;

  Future<void> fetchFeatured({int limit = 10}) async {
    isLoadingFeatured = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get(
        '/studios/featured',
        queryParameters: {'limit': limit},
      );
      featuredStudios = (response.data as List)
          .map((e) => StudioModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Section phụ trên Home — lỗi không cần chặn cả màn hình.
    } finally {
      isLoadingFeatured = false;
      notifyListeners();
    }
  }

  Future<void> fetchForYou({int limit = 10}) async {
    isLoadingForYou = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get(
        '/studios/for-you',
        queryParameters: {'limit': limit},
      );
      forYouStudios = (response.data as List)
          .map((e) => StudioModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Tương tự featured.
    } finally {
      isLoadingForYou = false;
      notifyListeners();
    }
  }

  Future<void> fetchStyleTags() async {
    isLoadingStyleTags = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get('/studios/style-tags');
      styleTags = (response.data as List).cast<String>();
    } catch (e) {
      // Không có danh mục cũng không sao.
    } finally {
      isLoadingStyleTags = false;
      notifyListeners();
    }
  }

  /// Ghi nhận lượt xem — gọi khi mở màn Chi tiết Studio. Thất bại (vd: mất
  /// mạng) không nên chặn trải nghiệm xem chi tiết, nên chỉ âm thầm bỏ qua.
  Future<void> recordView(String studioId) async {
    try {
      await _apiClient.dio.post('/studios/$studioId/view');
    } catch (e) {
      // Bỏ qua lỗi có chủ đích.
    }
  }

  // ---- Dữ liệu cho màn Chi tiết Studio ----
  // Không lưu vào state chung của Provider (không cần notifyListeners) vì
  // mỗi màn Chi tiết tự quản lý loading/error riêng theo từng studio_id.

  Future<StudioDetailModel?> fetchStudioDetail(String studioId) async {
    try {
      final response = await _apiClient.dio.get('/studios/$studioId');
      return StudioDetailModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<List<ReviewModel>> fetchReviews(String studioId, {int limit = 3}) async {
    try {
      final response = await _apiClient.dio.get(
        '/studios/$studioId/reviews',
        queryParameters: {'limit': limit},
      );
      final data = response.data as Map<String, dynamic>;
      return (data['data'] as List)
          .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
