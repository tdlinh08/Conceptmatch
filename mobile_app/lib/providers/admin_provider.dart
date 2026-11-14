import 'package:dio/dio.dart' show Options;
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/api_error.dart';
import '../models/admin_models.dart';
import '../models/stats_models.dart';
import 'owner_studios_provider.dart' show OwnerActionException;

/// Gọi API trang quản trị (/admin/*). Ném [OwnerActionException] (câu tiếng Việt) khi lỗi.
/// Giữ số studio chờ duyệt để hiện chấm đỏ trên thanh điều hướng.
class AdminProvider extends ChangeNotifier {
  final _api = ApiClient();

  int pendingStudios = 0;
  int pendingReports = 0;

  Future<T> _call<T>(Future<T> Function() fn, String fallback) async {
    try {
      return await fn();
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: fallback));
    }
  }

  Future<AdminDashboard> dashboard() => _call(() async {
        final res = await _api.dio.get('/admin/dashboard');
        final d = AdminDashboard.fromJson(res.data as Map<String, dynamic>);
        _setPending(d.pendingStudios);
        _setReports(d.pendingReports);
        return d;
      }, 'Không tải được số liệu tổng quan');

  /// Danh sách studio + số lượng theo trạng thái ({pending, active, rejected}).
  Future<({PageResult<AdminStudioRow> page, Map<String, int> counts})> studios({
    required String status,
    String? keyword,
    int page = 1,
    int limit = 20,
  }) =>
      _call(() async {
        final res = await _api.dio.get('/admin/studios', queryParameters: {
          'status': status,
          if ((keyword ?? '').trim().isNotEmpty) 'keyword': keyword!.trim(),
          'page': page,
          'limit': limit,
        });
        final data = res.data as Map<String, dynamic>;
        final counts = (data['counts'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, (v as num).toInt()));
        _setPending(counts['pending'] ?? pendingStudios);
        return (
          page: PageResult(
            (data['data'] as List)
                .map((e) => AdminStudioRow.fromJson(e as Map<String, dynamic>))
                .toList(),
            data['total'] as int,
          ),
          counts: counts,
        );
      }, 'Không tải được danh sách studio');

  Future<AdminStudioDetail> studio(String id) => _call(() async {
        final res = await _api.dio.get('/admin/studios/$id');
        return AdminStudioDetail.fromJson(res.data as Map<String, dynamic>);
      }, 'Không tải được thông tin studio');

  /// Duyệt studio. Trả về cảnh báo AI (vd dịch vụ AI chưa chạy) nếu có.
  Future<List<String>> approve(String id) => _call(() async {
        final res = await _api.dio.patch('/admin/studios/$id/approve');
        final w = (res.data as Map<String, dynamic>)['warnings'];
        return w is List ? w.map((e) => e.toString()).toList() : const <String>[];
      }, 'Không duyệt được studio');

  Future<void> reject(String id, String reason) => _call(
        () => _api.dio.patch('/admin/studios/$id/reject', data: {'reason': reason}),
        'Không từ chối được studio',
      );

  Future<void> takeDown(String id, String reason) => _call(
        () => _api.dio.patch('/admin/studios/$id/take-down', data: {'reason': reason}),
        'Không gỡ được studio',
      );

  Future<PageResult<AdminUserRow>> users({
    String? keyword,
    String? role,
    String? status,
    int page = 1,
    int limit = 20,
  }) =>
      _call(() async {
        final res = await _api.dio.get('/admin/users', queryParameters: {
          if ((keyword ?? '').trim().isNotEmpty) 'keyword': keyword!.trim(),
          'role': ?role,
          'status': ?status,
          'page': page,
          'limit': limit,
        });
        final data = res.data as Map<String, dynamic>;
        return PageResult(
          (data['data'] as List)
              .map((e) => AdminUserRow.fromJson(e as Map<String, dynamic>))
              .toList(),
          data['total'] as int,
        );
      }, 'Không tải được danh sách tài khoản');

  Future<AdminUserDetail> user(String id) => _call(() async {
        final res = await _api.dio.get('/admin/users/$id');
        return AdminUserDetail.fromJson(res.data as Map<String, dynamic>);
      }, 'Không tải được thông tin tài khoản');

  /// Đơn toàn sàn (chỉ xem). [from]/[to] lọc theo ngày chụp. Trả kèm tổng tiền các đơn khớp lọc.
  Future<({PageResult<AdminBookingRow> page, double totalAmount})> bookings({
    String? status,
    String? keyword,
    String? studioId,
    String? userId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 20,
  }) =>
      _call(() async {
        String d(DateTime x) =>
            '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
        final res = await _api.dio.get('/admin/bookings', queryParameters: {
          'status': ?status,
          if ((keyword ?? '').trim().isNotEmpty) 'keyword': keyword!.trim(),
          'studio_id': ?studioId,
          'user_id': ?userId,
          if (from != null) 'from': d(from),
          if (to != null) 'to': d(to),
          'page': page,
          'limit': limit,
        });
        final data = res.data as Map<String, dynamic>;
        return (
          page: PageResult(
            (data['data'] as List)
                .map((e) => AdminBookingRow.fromJson(e as Map<String, dynamic>))
                .toList(),
            data['total'] as int,
          ),
          totalAmount: (data['total_amount'] as num? ?? 0).toDouble(),
        );
      }, 'Không tải được danh sách đơn');

  Future<void> lockUser(String id, String reason) => _call(
        () => _api.dio.patch('/admin/users/$id/lock', data: {'reason': reason}),
        'Không khoá được tài khoản',
      );

  Future<void> unlockUser(String id) => _call(
        () => _api.dio.patch('/admin/users/$id/unlock'),
        'Không mở khoá được tài khoản',
      );

  Future<PageResult<AuditLogRow>> auditLogs({String? targetType, int page = 1, int limit = 30}) =>
      _call(() async {
        final res = await _api.dio.get('/admin/audit-logs', queryParameters: {
          'target_type': ?targetType,
          'page': page,
          'limit': limit,
        });
        final data = res.data as Map<String, dynamic>;
        return PageResult(
          (data['data'] as List)
              .map((e) => AuditLogRow.fromJson(e as Map<String, dynamic>))
              .toList(),
          data['total'] as int,
        );
      }, 'Không tải được nhật ký');

  /// Thống kê toàn sàn theo kỳ: '7d' | '30d' | '12m'.
  Future<StatsReport> stats(String range) => _call(() async {
        final res = await _api.dio.get('/stats/admin', queryParameters: {'range': range});
        return StatsReport.fromJson(res.data as Map<String, dynamic>);
      }, 'Không tải được thống kê');

  // ---- Báo cáo vi phạm + kiểm duyệt đánh giá ----

  Future<PageResult<ReportRow>> reports({required String status, int page = 1, int limit = 20}) =>
      _call(() async {
        final res = await _api.dio.get('/admin/reports', queryParameters: {
          'status': status,
          'page': page,
          'limit': limit,
        });
        final data = res.data as Map<String, dynamic>;
        _setReports((data['pending_count'] as num? ?? 0).toInt());
        return PageResult(
          (data['data'] as List).map((e) => ReportRow.fromJson(e as Map<String, dynamic>)).toList(),
          data['total'] as int,
        );
      }, 'Không tải được báo cáo');

  /// action: 'hide_review' | 'take_down' | 'none'
  Future<void> resolveReport(String id, String action, String note) => _call(
        () => _api.dio.patch('/admin/reports/$id/resolve', data: {'action': action, 'note': note}),
        'Không xử lý được báo cáo',
      );

  Future<void> dismissReport(String id, String note) => _call(
        () => _api.dio.patch('/admin/reports/$id/dismiss', data: {'note': note}),
        'Không cập nhật được báo cáo',
      );

  Future<void> hideReview(String id, String reason) => _call(
        () => _api.dio.patch('/admin/reviews/$id/hide', data: {'reason': reason}),
        'Không ẩn được đánh giá',
      );

  Future<void> unhideReview(String id) => _call(
        () => _api.dio.patch('/admin/reviews/$id/unhide'),
        'Không hiện lại được đánh giá',
      );

  /// Tạo lại vector AI cho mọi bối cảnh đang hoạt động. Trả về (số bối cảnh, cảnh báo).
  Future<({int sets, List<String> warnings})> reindexAi() => _call(() async {
        final res = await _api.dio.post(
          '/admin/ai/reindex',
          options: Options(receiveTimeout: const Duration(minutes: 10)),
        );
        final d = res.data as Map<String, dynamic>;
        return (
          sets: (d['sets'] as num).toInt(),
          warnings: (d['warnings'] as List).map((e) => e.toString()).toList(),
        );
      }, 'Không tạo lại được dữ liệu AI');

  void _setReports(int n) {
    if (n == pendingReports) return;
    pendingReports = n;
    notifyListeners();
  }

  void _setPending(int n) {
    if (n == pendingStudios) return;
    pendingStudios = n;
    notifyListeners();
  }

  void reset() {
    pendingStudios = 0;
    pendingReports = 0;
    notifyListeners();
  }
}
