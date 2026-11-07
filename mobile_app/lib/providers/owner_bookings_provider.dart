import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/api_error.dart';
import '../models/booking_models.dart';
import '../models/owner_booking_model.dart';
import 'owner_studios_provider.dart' show OwnerActionException;

/// Dữ liệu 1 tab (Chờ xác nhận / Sắp tới / Đã xong) — tải từng trang.
class OwnerBookingList {
  List<OwnerBookingItem> items = [];
  int total = 0;
  int page = 0;
  bool isLoading = false;
  bool loaded = false;
  String? error;

  bool get hasMore => !loaded || items.length < total;
}

/// Quản lý lịch đặt phía CHỦ STUDIO (GET /bookings/studio, PATCH /bookings/:id/status).
class OwnerBookingsProvider extends ChangeNotifier {
  static const _pageSize = 20;
  final _api = ApiClient();

  /// null = tất cả studio của tôi.
  String? studioId;

  final Map<OwnerBookingTab, OwnerBookingList> _lists = {
    for (final t in OwnerBookingTab.values) t: OwnerBookingList(),
  };

  OwnerBookingList list(OwnerBookingTab tab) => _lists[tab]!;

  /// Tải lại tab từ trang 1.
  Future<void> refresh(OwnerBookingTab tab) async {
    final l = _lists[tab]!;
    l.page = 0;
    l.loaded = false;
    l.total = 0;
    await _loadPage(tab, replace: true);
  }

  /// Cuộn gần cuối -> tải trang tiếp.
  Future<void> loadMore(OwnerBookingTab tab) async {
    final l = _lists[tab]!;
    if (l.isLoading || !l.hasMore || l.error != null) return;
    await _loadPage(tab, replace: false);
  }

  Future<void> _loadPage(OwnerBookingTab tab, {required bool replace}) async {
    final l = _lists[tab]!;
    l.isLoading = true;
    l.error = null;
    notifyListeners();
    try {
      final res = await _api.dio.get('/bookings/studio', queryParameters: {
        'group': tab.group,
        'page': l.page + 1,
        'limit': _pageSize,
        if (studioId != null) 'studio_id': studioId,
      });
      final data = res.data as Map<String, dynamic>;
      final items = (data['data'] as List)
          .map((e) => OwnerBookingItem.fromJson(e as Map<String, dynamic>))
          .toList();
      l.items = replace ? items : [...l.items, ...items];
      l.total = data['total'] as int;
      l.page++;
      l.loaded = true;
      if (items.isEmpty) l.total = l.items.length; // phòng khi total lệch -> không gọi mãi
    } catch (e) {
      l.error = apiErrorMessage(e, fallback: 'Không tải được danh sách đơn');
    } finally {
      l.isLoading = false;
      notifyListeners();
    }
  }

  /// Đổi bộ lọc studio -> tải lại mọi tab.
  Future<void> setStudio(String? id) async {
    if (id == studioId) return;
    studioId = id;
    await refreshAll();
  }

  Future<void> refreshAll() => Future.wait(OwnerBookingTab.values.map(refresh));

  // ---- Chi tiết + đổi trạng thái ----

  Future<BookingDetail> fetchDetail(String id) async {
    try {
      final res = await _api.dio.get('/bookings/$id');
      return BookingDetail.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: 'Không tải được chi tiết đơn'));
    }
  }

  Future<List<AvailableStaffLine>> availableStaff(String id) async {
    try {
      final res = await _api.dio.get('/bookings/$id/available-staff');
      return (res.data as List)
          .map((e) => AvailableStaffLine.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: 'Không tải được danh sách thợ'));
    }
  }

  /// Đổi trạng thái đơn. [assignments] = {role: staffId} khi xác nhận đơn có dịch vụ.
  Future<void> updateStatus(
    String id,
    String status, {
    String? reason,
    Map<String, String>? assignments,
  }) async {
    try {
      await _api.dio.patch('/bookings/$id/status', data: {
        'status': status,
        'cancel_reason': ?reason,
        if (assignments != null && assignments.isNotEmpty)
          'staff_assignments': [
            for (final e in assignments.entries) {'role': e.key, 'staff_id': e.value},
          ],
      });
    } catch (e) {
      throw OwnerActionException(apiErrorMessage(e, fallback: 'Không cập nhật được đơn'));
    }
    refreshAll(); // không chờ: danh sách cập nhật nền
  }

  void reset() {
    studioId = null;
    for (final t in OwnerBookingTab.values) {
      _lists[t] = OwnerBookingList();
    }
    notifyListeners();
  }
}
