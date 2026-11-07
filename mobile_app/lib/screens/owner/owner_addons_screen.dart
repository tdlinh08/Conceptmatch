import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/owner_studio_model.dart';
import '../../models/studio_detail_model.dart' show StaffRoles;
import '../../providers/owner_studios_provider.dart';
import 'owner_staff_screen.dart';
import 'widgets/owner_ui.dart';

/// Đơn vị tính của dịch vụ thêm (khớp enum AddonUnit ở backend).
const _units = {
  'per_booking': 'Theo lượt đặt',
  'per_hour': 'Theo giờ (nhân thời lượng gói)',
  'per_person': 'Theo người',
};

String _unitShort(String unit) => switch (unit) {
      'per_hour' => '/giờ',
      'per_person' => '/người',
      _ => '/lượt',
    };

/// Dịch vụ thêm khách tự chọn khi đặt (thợ ảnh chụp, trang điểm...).
class OwnerAddonsScreen extends StatefulWidget {
  final String studioId;

  const OwnerAddonsScreen({super.key, required this.studioId});

  @override
  State<OwnerAddonsScreen> createState() => _OwnerAddonsScreenState();
}

class _OwnerAddonsScreenState extends State<OwnerAddonsScreen> {
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

  Future<void> _open([OwnerAddon? addon]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _AddonFormScreen(studioId: widget.studioId, initial: addon)),
    );
    if (ok == true && mounted) {
      await _load();
      if (mounted) showToast(context, addon == null ? 'Đã thêm dịch vụ' : 'Đã lưu dịch vụ');
    }
  }

  Future<void> _openStaff() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OwnerStaffScreen(studioId: widget.studioId)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _studio;
    return Scaffold(
      appBar: AppBar(title: const Text('Dịch vụ thêm')),
      floatingActionButton: s == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _open(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm dịch vụ'),
            ),
      body: s == null
          ? LoadState(error: _error, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  const HintBox(
                    'Khách tick chọn dịch vụ khi đặt lịch. Mỗi dịch vụ cần 1 người đúng vai trò — '
                    'khi xác nhận đơn bạn sẽ chọn người cụ thể. Giá dịch vụ không bị phụ thu giờ tối / cuối tuần.',
                  ),
                  const SizedBox(height: 16),
                  if (s.addons.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'Chưa có dịch vụ nào.\nVí dụ: "Thợ ảnh chụp" 200.000đ/giờ, "Trang điểm" 300.000đ/người.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
                      ),
                    )
                  else
                    for (final a in s.addons)
                      _AddonTile(
                        addon: a,
                        noStaff: s.activeStaffOf(a.role) == 0,
                        onTap: () => _open(a),
                        onAddStaff: _openStaff,
                      ),
                ],
              ),
            ),
    );
  }
}

class _AddonTile extends StatelessWidget {
  final OwnerAddon addon;
  final bool noStaff;
  final VoidCallback onTap;
  final VoidCallback onAddStaff;

  const _AddonTile({
    required this.addon,
    required this.noStaff,
    required this.onTap,
    required this.onAddStaff,
  });

  @override
  Widget build(BuildContext context) {
    final a = addon;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: a.isActive ? 1 : 0.6,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.outline),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                a.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textTitle,
                                ),
                              ),
                            ),
                            if (!a.isActive) ...[const SizedBox(width: 6), const MutedTag('Đang ẩn')],
                          ],
                        ),
                      ),
                      Text(
                        '${Formatters.vnd(a.price)}${_unitShort(a.unit)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cần: ${StaffRoles.label(a.role).toLowerCase()}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                  ),
                  if (a.isActive && noStaff) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.statusWarning),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Chưa có người đang làm — khách chưa thấy dịch vụ này.',
                            style: TextStyle(fontSize: 12, color: AppColors.statusWarning),
                          ),
                        ),
                        TextButton(onPressed: onAddStaff, child: const Text('Thêm người')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddonFormScreen extends StatefulWidget {
  final String studioId;
  final OwnerAddon? initial;

  const _AddonFormScreen({required this.studioId, this.initial});

  @override
  State<_AddonFormScreen> createState() => _AddonFormScreenState();
}

class _AddonFormScreenState extends State<_AddonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late String _role;
  late String _unit;
  late bool _active;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _name = TextEditingController(text: a?.name ?? '');
    _price = TextEditingController(text: a == null ? '' : MoneyField.format(a.price));
    _description = TextEditingController(text: a?.description ?? '');
    _role = a?.role ?? StaffRoles.photographer;
    _unit = a?.unit ?? 'per_booking';
    _active = a?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final body = <String, dynamic>{
      'role': _role,
      'name': _name.text.trim(),
      'price': MoneyField.parseMoney(_price.text),
      'unit': _unit,
      'description': _description.text.trim(),
      if (_isEdit) 'is_active': _active,
    };
    setState(() => _saving = true);
    final provider = context.read<OwnerStudiosProvider>();
    try {
      if (_isEdit) {
        await provider.updateAddon(widget.studioId, widget.initial!.id, body);
      } else {
        await provider.createAddon(widget.studioId, body);
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
      appBar: AppBar(title: Text(_isEdit ? 'Sửa dịch vụ' : 'Thêm dịch vụ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const Text('Cần người thuộc vai trò', style: TextStyle(fontSize: 13, color: AppColors.textFaint)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final r in [StaffRoles.photographer, StaffRoles.makeup])
                  ButtonSegment(value: r, label: Text(StaffRoles.label(r))),
              ],
              selected: {_role},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _role = v.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tên dịch vụ *',
                hintText: 'vd: Thợ ảnh chụp, Trang điểm + làm tóc',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên dịch vụ' : null,
            ),
            const SizedBox(height: 14),
            MoneyField(controller: _price, label: 'Giá *', min: 1000),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Cách tính tiền'),
              items: [
                for (final e in _units.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _unit = v ?? _unit),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                hintText: 'vd: Gồm 30 ảnh chỉnh màu, giao file sau 3 ngày',
                alignLabelWithHint: true,
              ),
            ),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang bán'),
                subtitle: const Text('Tắt để ẩn dịch vụ với khách (đơn đã đặt giữ nguyên giá cũ)'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 20),
            SaveButton(label: _isEdit ? 'Lưu thay đổi' : 'Thêm dịch vụ', saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
