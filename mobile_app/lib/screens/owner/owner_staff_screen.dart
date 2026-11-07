import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/owner_studio_model.dart';
import '../../models/studio_detail_model.dart' show StaffRoles;
import '../../providers/owner_studios_provider.dart';
import 'widgets/owner_ui.dart';

/// Nhân sự của studio: thợ ảnh / thợ trang điểm. Nghỉ việc = tắt "Đang làm" (không xoá,
/// vì đơn cũ vẫn ghi tên người được phân công).
class OwnerStaffScreen extends StatefulWidget {
  final String studioId;

  const OwnerStaffScreen({super.key, required this.studioId});

  @override
  State<OwnerStaffScreen> createState() => _OwnerStaffScreenState();
}

class _OwnerStaffScreenState extends State<OwnerStaffScreen> {
  OwnerStudioDetail? _studio;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await context.read<OwnerStudiosProvider>().fetchDetail(widget.studioId);
      if (mounted) setState(() => _studio = s);
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open([OwnerStaff? staff]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _StaffFormScreen(studioId: widget.studioId, initial: staff)),
    );
    if (ok == true && mounted) {
      await _load();
      if (mounted) showToast(context, staff == null ? 'Đã thêm nhân sự' : 'Đã lưu nhân sự');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _studio;
    return Scaffold(
      appBar: AppBar(title: const Text('Nhân sự')),
      floatingActionButton: s == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _open(),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Thêm người'),
            ),
      body: s == null
          ? LoadState(error: _error, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  const HintBox(
                    'Số người ĐANG LÀM của mỗi vai trò quyết định có bao nhiêu khách đặt kèm dịch vụ '
                    'đó cùng một khung giờ. Khách không thấy tên / SĐT nhân sự cho tới khi bạn phân công.',
                  ),
                  for (final role in [StaffRoles.photographer, StaffRoles.makeup]) ...[
                    const SizedBox(height: 20),
                    OwnerSectionHeader(
                      StaffRoles.label(role),
                      trailing: '${s.activeStaffOf(role)} đang làm',
                    ),
                    const SizedBox(height: 6),
                    if (!s.staff.any((m) => m.role == role))
                      const Text(
                        'Chưa có ai.',
                        style: TextStyle(fontSize: 14, color: AppColors.textBody),
                      )
                    else
                      for (final m in s.staff.where((m) => m.role == role))
                        _StaffTile(staff: m, onTap: () => _open(m)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final OwnerStaff staff;
  final VoidCallback onTap;

  const _StaffTile({required this.staff, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = staff.fullName.trim();
    final initial = name.isEmpty ? '?' : name.split(' ').last[0].toUpperCase();
    return Opacity(
      opacity: staff.isActive ? 1 : 0.55,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.surfacePink,
          child: Text(
            initial,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentText),
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(staff.fullName, overflow: TextOverflow.ellipsis)),
            if (!staff.isActive) ...[const SizedBox(width: 6), const MutedTag('Đã nghỉ')],
          ],
        ),
        subtitle: Text((staff.phone ?? '').isEmpty ? 'Chưa có SĐT' : staff.phone!),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _StaffFormScreen extends StatefulWidget {
  final String studioId;
  final OwnerStaff? initial;

  const _StaffFormScreen({required this.studioId, this.initial});

  @override
  State<_StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<_StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late String _role;
  late bool _active;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _name = TextEditingController(text: m?.fullName ?? '');
    _phone = TextEditingController(text: m?.phone ?? '');
    _role = m?.role ?? StaffRoles.photographer;
    _active = m?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final body = <String, dynamic>{
      'full_name': _name.text.trim(),
      'role': _role,
      'phone': _phone.text.trim(),
      if (_isEdit) 'is_active': _active,
    };
    setState(() => _saving = true);
    final provider = context.read<OwnerStudiosProvider>();
    try {
      if (_isEdit) {
        await provider.updateStaff(widget.studioId, widget.initial!.id, body);
      } else {
        await provider.createStaff(widget.studioId, body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on OwnerActionException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa nhân sự' : 'Thêm nhân sự')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            SegmentedButton<String>(
              segments: [
                for (final r in [StaffRoles.photographer, StaffRoles.makeup])
                  ButtonSegment(value: r, label: Text(StaffRoles.label(r))),
              ],
              selected: {_role},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _role = v.first),
            ),
            if (_isEdit)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Người đã được phân công đơn thì không đổi vai trò được — hãy thêm người mới.',
                  style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Họ tên *', counterText: ''),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập họ tên' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 20,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                helperText: 'Chỉ chủ studio thấy; khách thấy sau khi được phân công',
                counterText: '',
              ),
            ),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang làm'),
                subtitle: const Text('Tắt khi người này nghỉ — không được phân công đơn mới'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 20),
            SaveButton(label: _isEdit ? 'Lưu thay đổi' : 'Thêm', saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
