import '../core/constants/api_constants.dart';
import 'owner_studio_model.dart';

DateTime _date(Object? v) => DateTime.parse(v as String).toLocal();

/// Trang tổng quan (GET /admin/dashboard).
class AdminDashboard {
  final int activeStudios;
  final int pendingStudios;
  final int totalUsers;
  final int newUsersThisMonth;
  final int bookingsToday;
  final double revenueThisMonth;
  final Map<String, int> usersByRole; // user / studio_owner / admin
  final Map<String, int> bookingsThisMonth; // theo trạng thái
  final List<({String name, int bookings, double rating})> topStudios;

  AdminDashboard({
    required this.activeStudios,
    required this.pendingStudios,
    required this.totalUsers,
    required this.newUsersThisMonth,
    required this.bookingsToday,
    required this.revenueThisMonth,
    required this.usersByRole,
    required this.bookingsThisMonth,
    required this.topStudios,
  });

  static Map<String, int> _counts(Object? v) =>
      (v as Map<String, dynamic>? ?? const {}).map((k, n) => MapEntry(k, (n as num).toInt()));

  factory AdminDashboard.fromJson(Map<String, dynamic> j) => AdminDashboard(
        activeStudios: j['total_studios'] as int? ?? 0,
        pendingStudios: j['pending_studios'] as int? ?? 0,
        totalUsers: j['total_users'] as int? ?? 0,
        newUsersThisMonth: j['new_users_this_month'] as int? ?? 0,
        bookingsToday: j['total_bookings_today'] as int? ?? 0,
        revenueThisMonth: (j['revenue_this_month'] as num? ?? 0).toDouble(),
        usersByRole: _counts(j['users_by_role']),
        bookingsThisMonth: _counts(j['bookings_this_month']),
        topStudios: (j['top_studios'] as List? ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .map((e) => (
                  name: e['name'] as String? ?? '',
                  bookings: (e['booking_count'] as num? ?? 0).toInt(),
                  rating: (e['avg_rating'] as num? ?? 0).toDouble(),
                ))
            .toList(),
      );
}

/// 1 dòng trong danh sách studio của admin (GET /admin/studios).
class AdminStudioRow {
  final String id;
  final String name;
  final String district;
  final String address;
  final String status;
  final String? rejectReason;
  final DateTime createdAt;
  final String ownerName;
  final String ownerEmail;
  final String? coverImage;
  final int setCount;
  final int imageCount;
  final int bookingCount;

  AdminStudioRow({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.status,
    this.rejectReason,
    required this.createdAt,
    required this.ownerName,
    required this.ownerEmail,
    this.coverImage,
    required this.setCount,
    required this.imageCount,
    required this.bookingCount,
  });

  factory AdminStudioRow.fromJson(Map<String, dynamic> j) {
    final owner = j['owner'] as Map<String, dynamic>? ?? const {};
    return AdminStudioRow(
      id: j['id'] as String,
      name: j['name'] as String,
      district: j['district'] as String,
      address: j['address'] as String,
      status: j['status'] as String,
      rejectReason: j['reject_reason'] as String?,
      createdAt: _date(j['created_at']),
      ownerName: owner['full_name'] as String? ?? '',
      ownerEmail: owner['email'] as String? ?? '',
      coverImage: ApiConstants.mediaUrl(j['cover_image'] as String?),
      setCount: j['set_count'] as int? ?? 0,
      imageCount: j['image_count'] as int? ?? 0,
      bookingCount: j['booking_count'] as int? ?? 0,
    );
  }
}

/// Chi tiết studio cho admin = dữ liệu như chủ studio thấy + thông tin chủ studio.
class AdminStudioDetail {
  final OwnerStudioDetail studio;
  final String ownerName;
  final String ownerEmail;
  final String ownerStatus; // active | locked
  final DateTime? createdAt;

  AdminStudioDetail({
    required this.studio,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerStatus,
    this.createdAt,
  });

  factory AdminStudioDetail.fromJson(Map<String, dynamic> j) {
    final owner = j['owner'] as Map<String, dynamic>? ?? const {};
    return AdminStudioDetail(
      studio: OwnerStudioDetail.fromJson(j),
      ownerName: owner['full_name'] as String? ?? '',
      ownerEmail: owner['email'] as String? ?? '',
      ownerStatus: owner['status'] as String? ?? 'active',
      createdAt: j['created_at'] == null ? null : _date(j['created_at']),
    );
  }
}

/// Tài khoản (GET /admin/users).
class AdminUserRow {
  final String id;
  final String fullName;
  final String email;
  final String role; // user | studio_owner | admin
  final String status; // active | locked
  final DateTime createdAt;

  AdminUserRow({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  bool get isLocked => status == 'locked';

  static String roleLabel(String role) => switch (role) {
        'studio_owner' => 'Chủ studio',
        'admin' => 'Quản trị viên',
        _ => 'Khách hàng',
      };

  factory AdminUserRow.fromJson(Map<String, dynamic> j) => AdminUserRow(
        id: j['id'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        status: j['status'] as String,
        createdAt: _date(j['created_at']),
      );
}

/// 1 dòng nhật ký thao tác của admin.
class AuditLogRow {
  final String action;
  final String targetType; // studio | user
  final String? targetName;
  final String? note;
  final String adminName;
  final DateTime createdAt;

  AuditLogRow({
    required this.action,
    required this.targetType,
    this.targetName,
    this.note,
    required this.adminName,
    required this.createdAt,
  });

  factory AuditLogRow.fromJson(Map<String, dynamic> j) => AuditLogRow(
        action: j['action'] as String,
        targetType: j['target_type'] as String,
        targetName: j['target_name'] as String?,
        note: j['note'] as String?,
        adminName: j['admin_name'] as String? ?? '',
        createdAt: _date(j['created_at']),
      );
}

/// Một trang kết quả + tổng số.
class PageResult<T> {
  final List<T> items;
  final int total;
  const PageResult(this.items, this.total);
}
