import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/studio_model.dart';
import '../models/studio_detail_model.dart';
import '../models/review_model.dart';

/// Bộ lọc của màn "Tất cả studio" (khớp query của GET /studios).
class StudioFilter {
  final String keyword; // tìm không dấu theo tên, quận, địa chỉ, tên set, concept
  final String? styleTag;
  final String? district;
  final int? maxPrice; // có ít nhất 1 gói giá <= maxPrice
  final double? minRating;
  final Set<String> services; // 'photographer', 'makeup': studio có thợ + đang bán dịch vụ đó
  final String sort; // 'rating' (mặc định) | 'newest'

  const StudioFilter({
    this.keyword = '',
    this.styleTag,
    this.district,
    this.maxPrice,
    this.minRating,
    this.services = const {},
    this.sort = 'rating',
  });

  /// Số bộ lọc trong bảng "Bộ lọc" đang bật (không tính từ khoá, concept, sắp xếp).
  int get sheetCount =>
      [district, maxPrice, minRating].where((v) => v != null).length + services.length;

  bool get isEmpty => keyword.isEmpty && styleTag == null && sheetCount == 0;

  StudioFilter copyWith({
    String? keyword,
    String? Function()? styleTag, // truyền hàm để đặt được giá trị null
    String? Function()? district,
    int? Function()? maxPrice,
    double? Function()? minRating,
    Set<String>? services,
    String? sort,
  }) {
    return StudioFilter(
      keyword: keyword ?? this.keyword,
      styleTag: styleTag != null ? styleTag() : this.styleTag,
      district: district != null ? district() : this.district,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      minRating: minRating != null ? minRating() : this.minRating,
      services: services ?? this.services,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toQuery() => {
        if (keyword.isNotEmpty) 'keyword': keyword,
        if (styleTag != null) 'style_tag': styleTag,
        if (district != null) 'district': district,
        if (maxPrice != null) 'max_price': maxPrice,
        if (minRating != null) 'min_rating': minRating,
        if (services.isNotEmpty) 'services': (services.toList()..sort()).join(','),
        'sort': sort,
      };
}

class StudiosProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // ---- Danh sách đầy đủ (màn "Tất cả studio", có lọc + tải thêm khi cuộn) ----
  static const int _pageSize = 10;

  List<StudioModel> studios = [];
  bool isLoading = false;
  String? errorMessage;
  StudioFilter filter = const StudioFilter();
  int totalCount = 0;

  int _page = 1;
  bool _hasMore = true;
  int _requestId = 0; // đổi bộ lọc khi đang tải -> bỏ kết quả của lần gọi cũ

  bool get hasMore => _hasMore;

  /// Lọc mới (xoá danh sách cũ). Luôn chạy, kể cả khi lần tải trước chưa xong.
  Future<void> applyFilter(StudioFilter newFilter) async {
    filter = newFilter;
    _page = 1;
    _hasMore = true;
    studios = [];
    totalCount = 0;
    await _fetchPage(++_requestId);
  }

  /// Tải trang tiếp theo khi cuộn gần cuối.
  Future<void> loadMore() async {
    if (!_hasMore || isLoading) return;
    await _fetchPage(_requestId);
  }

  Future<void> _fetchPage(int requestId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(
        '/studios',
        queryParameters: {...filter.toQuery(), 'page': _page, 'limit': _pageSize},
      );
      if (requestId != _requestId) return; // đã có bộ lọc mới hơn

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] as List)
          .map((e) => StudioModel.fromJson(e as Map<String, dynamic>))
          .toList();
      totalCount = data['total'] as int;
      studios = [...studios, ...items];
      _hasMore = studios.length < totalCount;
      _page++;
    } catch (e) {
      if (requestId != _requestId) return;
      errorMessage = 'Không tải được danh sách studio. Kiểm tra lại kết nối.';
    } finally {
      if (requestId == _requestId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  // ---- Dữ liệu cho màn Home (nổi bật / danh mục / gợi ý cá nhân hoá) ----

  List<StudioModel> featuredStudios = [];
  List<StudioModel> forYouStudios = [];
  List<String> styleTags = [];

  bool isLoadingFeatured = false;
  bool isLoadingForYou = false;
  bool isLoadingStyleTags = false;

  // Xem nhanh 1 concept ngay trên Home (bấm chip Vintage / Retro…), lưu theo concept
  // để bấm qua lại giữa các chip không phải tải lại.
  final Map<String, List<StudioModel>> conceptPreviews = {};
  final Map<String, int> conceptTotals = {};
  final Set<String> _loadingConcepts = {};

  bool isLoadingConcept(String tag) => _loadingConcepts.contains(tag);

  Future<void> fetchConceptPreview(String tag, {int limit = 6, bool force = false}) async {
    if (_loadingConcepts.contains(tag)) return;
    if (!force && conceptPreviews.containsKey(tag)) return;
    _loadingConcepts.add(tag);
    notifyListeners();
    try {
      final response = await _apiClient.dio.get(
        '/studios',
        queryParameters: {'style_tag': tag, 'page': 1, 'limit': limit},
      );
      final data = response.data as Map<String, dynamic>;
      conceptPreviews[tag] = (data['data'] as List)
          .map((e) => StudioModel.fromJson(e as Map<String, dynamic>))
          .toList();
      conceptTotals[tag] = data['total'] as int;
    } catch (e) {
      // Mục phụ trên Home: lỗi thì để trống, người dùng vẫn bấm "Xem thêm" được.
    } finally {
      _loadingConcepts.remove(tag);
      notifyListeners();
    }
  }

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
