import '../core/constants/api_constants.dart';
import '../core/utils/formatters.dart';
import 'booking_models.dart';

/// Tab quản lý đơn của chủ studio (khớp tham số group của GET /bookings/studio).
enum OwnerBookingTab {
  pending('pending', 'Chờ xác nhận'),
  upcoming('upcoming', 'Sắp tới'),
  past('past', 'Đã xong');

  const OwnerBookingTab(this.group, this.label);
  final String group;
  final String label;
}

/// 1 đơn trong danh sách của chủ studio (GET /bookings/studio).
class OwnerBookingItem {
  final String id;
  final String studioId;
  final String studioName;
  final String setName;
  final String? packageName;
  final int numPeople;
  final String customerName;
  final String? customerAvatar;
  final DateTime startTime;
  final DateTime endTime;
  final double totalAmount;
  final String status;
  final String? specialNote;
  final String? cancelReason;
  final List<BookingAddonLine> addons;

  OwnerBookingItem({
    required this.id,
    required this.studioId,
    required this.studioName,
    required this.setName,
    this.packageName,
    required this.numPeople,
    required this.customerName,
    this.customerAvatar,
    required this.startTime,
    required this.endTime,
    required this.totalAmount,
    required this.status,
    this.specialNote,
    this.cancelReason,
    required this.addons,
  });

  /// Đơn còn hiệu lực nhưng đã qua giờ (studio chưa xử lý).
  bool get isOverdue {
    final now = DateTime.now();
    if (status == 'pending') return !startTime.isAfter(now); // quá giờ bắt đầu: không xác nhận được nữa
    if (status == 'confirmed' || status == 'checked_in') return endTime.isBefore(now);
    return false;
  }

  /// Nhãn hiển thị (dùng chung BookingStatusBadge): đơn chờ quá giờ -> "Quá hạn",
  /// đơn đã xác nhận quá giờ kết thúc -> "Chờ cập nhật".
  String get displayStatus {
    if (!isOverdue) return status;
    return status == 'pending' ? 'expired' : 'awaiting_update';
  }

  /// Đơn có dịch vụ chưa phân công người.
  bool get needsStaff => addons.any((a) => a.staffName == null);

  factory OwnerBookingItem.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};
    return OwnerBookingItem(
      id: json['id'] as String,
      studioId: json['studio_id'] as String,
      studioName: json['studio_name'] as String,
      setName: json['set_name'] as String,
      packageName: json['package_name'] as String?,
      numPeople: json['num_people'] as int? ?? 1,
      customerName: customer['full_name'] as String? ?? 'Khách',
      customerAvatar: ApiConstants.mediaUrl(customer['avatar_url'] as String?),
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      totalAmount: Formatters.money(json['total_amount']),
      status: json['status'] as String,
      specialNote: json['special_note'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      addons: BookingAddonLine.listFrom(json['addons']),
    );
  }
}

/// Người rảnh cho 1 dịch vụ của đơn (GET /bookings/:id/available-staff).
class StaffChoice {
  final String id;
  final String fullName;
  final String? phone;
  StaffChoice({required this.id, required this.fullName, this.phone});
}

class AvailableStaffLine {
  final String name; // tên dịch vụ, vd "Thợ ảnh chụp"
  final String role; // photographer | makeup
  final List<StaffChoice> staff;

  AvailableStaffLine({required this.name, required this.role, required this.staff});

  factory AvailableStaffLine.fromJson(Map<String, dynamic> json) => AvailableStaffLine(
        name: json['name'] as String,
        role: json['role'] as String,
        staff: (json['staff'] as List? ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .map((e) => StaffChoice(
                  id: e['id'] as String,
                  fullName: e['full_name'] as String,
                  phone: e['phone'] as String?,
                ))
            .toList(),
      );
}
