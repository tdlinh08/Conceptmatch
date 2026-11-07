import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/districts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/owner_studio_model.dart';
import '../../providers/owner_studios_provider.dart';

/// Form TẠO MỚI (initial == null) hoặc SỬA thông tin studio.
/// Tạo xong trả về id studio mới qua Navigator.pop; sửa xong trả về true.
class StudioFormScreen extends StatefulWidget {
  final OwnerStudioDetail? initial;

  const StudioFormScreen({super.key, this.initial});

  @override
  State<StudioFormScreen> createState() => _StudioFormScreenState();
}

class _StudioFormScreenState extends State<StudioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _description;
  late final TextEditingController _eveningPct;
  late final TextEditingController _weekendPct;

  String? _district;
  late String _open;
  late String _close;
  late String _eveningStart;
  late bool _open24h;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _name = TextEditingController(text: s?.name ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _eveningPct = TextEditingController(text: '${s?.eveningSurchargePct ?? 0}');
    _weekendPct = TextEditingController(text: '${s?.weekendSurchargePct ?? 0}');
    _district = s?.district;
    _open24h = s?.isOpen24h ?? false;
    _open = s?.openTime ?? '08:00';
    _close = s?.closeTime ?? '22:00';
    _eveningStart = s?.eveningStartTime ?? '18:00';
    if (_open24h) {
      // Giữ giờ hợp lý để nếu tắt 24/7 thì không hiện "00:00 – 24:00"
      _open = '08:00';
      _close = '22:00';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _description, _eveningPct, _weekendPct]) {
      c.dispose();
    }
    super.dispose();
  }

  static int _minutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<String?> _pickTime(String current, {bool allowMidnightEnd = false}) async {
    final parts = current == '24:00' ? [0, 0] : current.split(':').map(int.parse).toList();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
      helpText: 'Chọn giờ',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return null;
    // Giờ đóng cửa chọn 00:00 = nửa đêm -> lưu "24:00"
    if (allowMidnightEnd && picked.hour == 0 && picked.minute == 0) return '24:00';
    return _fmt(picked);
  }

  String? _validateHours() {
    if (_open24h) return null;
    if (_minutes(_close) - _minutes(_open) < 60) {
      return 'Giờ đóng cửa phải sau giờ mở cửa ít nhất 1 tiếng (không mở qua nửa đêm).';
    }
    return null;
  }

  int _pct(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final hoursError = _validateHours();
    final valid = _formKey.currentState!.validate();
    if (hoursError != null) {
      _toast(hoursError);
      return;
    }
    if (!valid) return;

    final form = StudioFormData(
      name: _name.text.trim(),
      address: _address.text.trim(),
      district: _district!,
      phone: _phone.text.trim(),
      description: _description.text.trim(),
      openTime: _open24h ? '00:00' : _open,
      closeTime: _open24h ? '24:00' : _close,
      eveningStartTime: _eveningStart,
      eveningSurchargePct: _pct(_eveningPct),
      weekendSurchargePct: _pct(_weekendPct),
    );

    setState(() => _saving = true);
    final provider = context.read<OwnerStudiosProvider>();
    try {
      if (_isEdit) {
        await provider.updateStudio(widget.initial!.id, form);
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        final id = await provider.createStudio(form);
        if (!mounted) return;
        Navigator.of(context).pop(id);
      }
    } on OwnerActionException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final rejected = widget.initial?.status == StudioStatus.rejected;
    // Quận cũ không có trong danh sách (dữ liệu nhập tay) -> vẫn hiện được
    final districts = [
      ...kDistricts,
      if (_district != null && !kDistricts.contains(_district)) _district!,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa thông tin studio' : 'Tạo studio mới')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (!_isEdit)
              const _Note(
                'Studio mới ở trạng thái "Chờ duyệt". Sau khi tạo, hãy thêm ảnh, bối cảnh và gói thuê '
                'để quản trị viên duyệt và khách nhìn thấy studio.',
              ),
            if (rejected)
              const _Note(
                'Studio đang bị từ chối. Lưu thay đổi sẽ tự gửi duyệt lại.',
                warning: true,
              ),
            const _Section('Thông tin chung'),
            TextFormField(
              controller: _name,
              maxLength: 150,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Tên studio *', counterText: ''),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên studio' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ *',
                hintText: 'Số nhà, đường, phường',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập địa chỉ' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _district,
              decoration: const InputDecoration(labelText: 'Quận *'),
              items: [
                for (final d in districts) DropdownMenuItem(value: d, child: Text(d)),
              ],
              onChanged: (v) => setState(() => _district = v),
              validator: (v) => v == null ? 'Chọn quận' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 20,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
              decoration: const InputDecoration(labelText: 'Số điện thoại *', counterText: ''),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.isEmpty) return 'Nhập số điện thoại';
                if (digits.length < 9 || digits.length > 12) return 'Số điện thoại không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Giới thiệu',
                hintText: 'Phong cách, diện tích, tiện ích (phòng thay đồ, đèn, đạo cụ...)',
                alignLabelWithHint: true,
              ),
            ),

            const _Section('Giờ mở cửa'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mở cửa 24/7'),
              value: _open24h,
              onChanged: (v) => setState(() => _open24h = v),
            ),
            if (!_open24h)
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Mở cửa',
                      value: _open,
                      onTap: () async {
                        final t = await _pickTime(_open);
                        if (t != null) setState(() => _open = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'Đóng cửa',
                      value: _close,
                      onTap: () async {
                        final t = await _pickTime(_close, allowMidnightEnd: true);
                        if (t != null) setState(() => _close = t);
                      },
                    ),
                  ),
                ],
              ),

            const _Section('Phụ thu'),
            const Text(
              'Giá gói thuê được cộng thêm % nếu giờ BẮT ĐẦU từ giờ tối trở đi, và vào thứ 7, chủ nhật. '
              'Để 0 nếu không phụ thu.',
              style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textBody),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Giờ tối từ',
                    value: _eveningStart,
                    onTap: () async {
                      final t = await _pickTime(_eveningStart);
                      if (t != null) setState(() => _eveningStart = t);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _PctField(controller: _eveningPct, label: 'Phụ thu giờ tối')),
              ],
            ),
            const SizedBox(height: 14),
            _PctField(controller: _weekendPct, label: 'Phụ thu cuối tuần'),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(_isEdit ? 'Lưu thay đổi' : 'Tạo studio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.textTitle,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final bool warning;
  const _Note(this.text, {this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? AppColors.statusWarning.withValues(alpha: 0.1) : AppColors.surfacePink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: warning ? AppColors.statusWarning : AppColors.textBody,
        ),
      ),
    );
  }
}

/// Ô chọn giờ (bấm mở đồng hồ 24 giờ).
class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule_rounded),
        ),
        child: Text(value, style: const TextStyle(fontSize: 16, color: AppColors.textTitle)),
      ),
    );
  }
}

/// Ô nhập % phụ thu 0–200 (khớp kiểm tra ở backend).
class _PctField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _PctField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      validator: (v) {
        final n = int.tryParse((v ?? '').trim());
        if (n == null) return 'Nhập số (0 nếu không phụ thu)';
        if (n > 200) return 'Tối đa 200%';
        return null;
      },
    );
  }
}
