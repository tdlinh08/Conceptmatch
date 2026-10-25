class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String role;

  /// Đường dẫn ảnh đại diện. Ảnh tải lên máy chủ là đường dẫn tương đối
  /// ("/uploads/avatars/..."), ảnh Google là link đầy đủ -> dùng
  /// ApiConstants.mediaUrl() để ra địa chỉ hiển thị được.
  final String? avatarUrl;

  /// false = tài khoản đăng nhập bằng Google, không có mật khẩu để đổi.
  final bool hasPassword;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.hasPassword = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatar_url'] as String?,
      hasPassword: json['has_password'] as bool? ?? true,
    );
  }
}
