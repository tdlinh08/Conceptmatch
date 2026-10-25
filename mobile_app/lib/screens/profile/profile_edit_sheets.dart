import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

// =============================================================================
// Khung chung cho các bảng kéo lên từ dưới
// =============================================================================

Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true, // để bảng đẩy lên trên bàn phím
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => child,
  );
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SheetFrame({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + keyboard),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buttonChild(bool busy, String label) => busy
    ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
      )
    : Text(label);

// =============================================================================
// 1. Đổi tên
// =============================================================================

/// Trả về true nếu đã đổi tên thành công.
Future<bool?> showEditNameSheet(BuildContext context) =>
    _showSheet<bool>(context, const _EditNameSheet());

class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet();

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<AuthProvider>().currentUser?.fullName ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<AuthProvider>().updateFullName(_controller.text.trim());
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Đổi họ tên',
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            enabled: !_saving,
            maxLength: 100, // khớp @MaxLength(100) ở backend
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Họ và tên',
              errorText: _error,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Họ tên không được để trống' : null,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saving ? null : _save, child: _buttonChild(_saving, 'Lưu')),
      ],
    );
  }
}

// =============================================================================
// 2. Đổi mật khẩu
// =============================================================================

/// Trả về true nếu đã đổi mật khẩu thành công.
Future<bool?> showChangePasswordSheet(BuildContext context) =>
    _showSheet<bool>(context, const _ChangePasswordSheet());

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<AuthProvider>().changePassword(
          currentPassword: _current.text,
          newPassword: _new.text,
        );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    return _SheetFrame(
      title: 'Đổi mật khẩu',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(labelText: 'Mật khẩu hiện tại', suffixIcon: toggle),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu hiện tại' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new,
                obscureText: _obscure,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới',
                  helperText: 'Tối thiểu 8 ký tự',
                ),
                validator: (v) {
                  if (v == null || v.length < 8) return 'Mật khẩu mới tối thiểu 8 ký tự';
                  if (v == _current.text) return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
                validator: (v) => v != _new.text ? 'Mật khẩu nhập lại không khớp' : null,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.statusError)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _buttonChild(_saving, 'Đổi mật khẩu'),
        ),
      ],
    );
  }
}

// =============================================================================
// 3. Đổi ảnh đại diện
// =============================================================================

/// Lỗi khi không mở được máy ảnh / thư viện (thường do bị từ chối quyền).
class AvatarPickException implements Exception {
  final String message;
  AvatarPickException(this.message);
}

/// Hỏi chọn ảnh từ thư viện hay chụp mới. Trả về đường dẫn ảnh trên máy,
/// hoặc null nếu người dùng huỷ. Việc tải lên do màn gọi tự làm (để chỉ hiện
/// vòng xoay đúng lúc đang tải, không hiện trong lúc còn đang chọn ảnh).
Future<String?> pickAvatarImage(BuildContext context) async {
  final source = await _showSheet<ImageSource>(
    context,
    const _SheetFrame(
      title: 'Ảnh đại diện',
      children: [
        _SourceTile(
          icon: Icons.photo_library_outlined,
          label: 'Chọn từ thư viện',
          source: ImageSource.gallery,
        ),
        SizedBox(height: 8),
        _SourceTile(
          icon: Icons.photo_camera_outlined,
          label: 'Chụp ảnh mới',
          source: ImageSource.camera,
        ),
      ],
    ),
  );
  if (source == null) return null;

  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      // Thu nhỏ + nén ngay trên máy: ảnh đại diện chỉ hiển thị nhỏ, gửi ảnh
      // 12MP gốc vừa chậm vừa dễ vượt giới hạn 5MB của backend.
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    return picked?.path;
  } catch (_) {
    throw AvatarPickException(
      'Không mở được ${source == ImageSource.camera ? 'máy ảnh' : 'thư viện ảnh'}. '
      'Kiểm tra quyền truy cập của ứng dụng trong Cài đặt.',
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final ImageSource source;

  const _SourceTile({required this.icon, required this.label, required this.source});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pop(source),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.textTitle),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
