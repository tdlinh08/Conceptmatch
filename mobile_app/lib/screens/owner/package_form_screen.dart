import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/owner_studio_model.dart';
import '../../providers/owner_studios_provider.dart';
import 'widgets/owner_ui.dart';

/// Form TẠO / SỬA gói thuê của 1 bối cảnh. Lưu xong pop(true).
/// Kiểm tra giống backend: thời lượng bội số 30 phút và không dài hơn giờ mở cửa,
/// số người đã gồm ≤ tối đa ≤ sức chứa bối cảnh.
class PackageFormScreen extends StatefulWidget {
  final String studioId;
  final OwnerSet set;
  final int openMinutes; // số phút mở cửa mỗi ngày của studio
  final OwnerPackage? initial;

  const PackageFormScreen({
    super.key,
    required this.studioId,
    required this.set,
    required this.openMinutes,
    this.initial,
  });

  @override
  State<PackageFormScreen> createState() => _PackageFormScreenState();
}

class _PackageFormScreenState extends State<PackageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _included;
  late final TextEditingController _extraFee;
  late final TextEditingController _max;
  late int _duration;
  late bool _active;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  /// Các thời lượng chọn được: 30 phút -> min(giờ mở cửa, 24 giờ).
  List<int> get _durations {
    final limit = widget.openMinutes.clamp(30, 1440).toInt();
    return [for (var m = 30; m <= limit; m += 30) m];
  }

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    final cap = widget.set.capacity;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p == null ? '' : MoneyField.format(p.price));
    _included = TextEditingController(text: '${p?.includedPeople ?? (cap < 2 ? cap : 2)}');
    _extraFee = TextEditingController(text: MoneyField.format(p?.extraPersonFee ?? 0));
    _max = TextEditingController(text: '${p?.maxPeople ?? cap}');
    _active = p?.isActive ?? true;
    final options = _durations;
    _duration = p?.durationMinutes ?? 60;
    if (!options.contains(_duration)) _duration = options.contains(60) ? 60 : options.first;
    for (final c in [_price, _included, _extraFee, _max]) {
      c.addListener(() => setState(() {})); // cập nhật dòng "ví dụ giá"
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _included, _extraFee, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  /// "Ví dụ: 2 người 300.000đ · 4 người 400.000đ (chưa gồm phụ thu)".
  String? _example() {
    final price = MoneyField.parseMoney(_price.text);
    final inc = int.tryParse(_included.text);
    final max = int.tryParse(_max.text);
    final fee = MoneyField.parseMoney(_extraFee.text) ?? 0;
    if (price == null || inc == null || max == null || max < inc) return null;
    final first = '$inc người ${Formatters.vnd(price)}';
    if (max == inc || fee == 0) return 'Giá: $first (chưa gồm phụ thu giờ tối / cuối tuần)';
    return 'Ví dụ: $first · $max người ${Formatters.vnd(price + (max - inc) * fee)} '
        '(chưa gồm phụ thu)';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'duration_minutes': _duration,
      'price': MoneyField.parseMoney(_price.text),
      'included_people': int.parse(_included.text),
      'extra_person_fee': MoneyField.parseMoney(_extraFee.text) ?? 0,
      'max_people': int.parse(_max.text),
      if (_isEdit) 'is_active': _active,
    };
    setState(() => _saving = true);
    final provider = context.read<OwnerStudiosProvider>();
    try {
      if (_isEdit) {
        await provider.updatePackage(widget.studioId, widget.set.id, widget.initial!.id, body);
      } else {
        await provider.createPackage(widget.studioId, widget.set.id, body);
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
    final cap = widget.set.capacity;
    final example = _example();
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa gói thuê' : 'Thêm gói thuê')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(
              'Bối cảnh: ${widget.set.name} · sức chứa $cap người',
              style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tên gói *',
                hintText: 'vd: Gói 1 giờ, Nửa ngày, Gói cặp đôi',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên gói' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: const InputDecoration(labelText: 'Thời lượng *'),
              menuMaxHeight: 320,
              items: [
                for (final m in _durations)
                  DropdownMenuItem(value: m, child: Text(Formatters.duration(m))),
              ],
              onChanged: (v) => setState(() => _duration = v ?? _duration),
            ),
            const SizedBox(height: 14),
            MoneyField(controller: _price, label: 'Giá gói *', min: 1000),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: IntField(
                    controller: _included,
                    label: 'Số người đã gồm *',
                    min: 1,
                    max: cap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: IntField(
                    controller: _max,
                    label: 'Tối đa *',
                    min: 1,
                    max: cap,
                    helper: '≤ sức chứa ($cap)',
                    extraValidator: (n) {
                      final inc = int.tryParse(_included.text) ?? 1;
                      return n < inc ? 'Phải ≥ số người đã gồm' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            MoneyField(
              controller: _extraFee,
              label: 'Phụ thu mỗi người thêm',
              helper: 'Cộng cho mỗi người vượt "số người đã gồm". 0 = không thu.',
            ),
            if (example != null) ...[
              const SizedBox(height: 12),
              HintBox(example, icon: Icons.calculate_outlined),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mô tả gói',
                hintText: 'vd: Gồm 2 bộ trang phục, miễn phí đạo cụ',
                alignLabelWithHint: true,
              ),
            ),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang bán'),
                subtitle: const Text('Tắt để ẩn gói với khách (đơn đã đặt không bị ảnh hưởng)'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 20),
            SaveButton(label: _isEdit ? 'Lưu thay đổi' : 'Thêm gói', saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
