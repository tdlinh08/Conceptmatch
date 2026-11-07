import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/owner_studio_model.dart';
import '../../providers/owner_studios_provider.dart';
import 'widgets/owner_ui.dart';
import 'widgets/pick_images.dart';

/// Form TẠO (initial == null) / SỬA bối cảnh. Lưu xong pop(true).
class SetFormScreen extends StatefulWidget {
  final String studioId;
  final OwnerSet? initial;

  const SetFormScreen({super.key, required this.studioId, this.initial});

  @override
  State<SetFormScreen> createState() => _SetFormScreenState();
}

class _SetFormScreenState extends State<SetFormScreen> {
  static const _defaultTags = ['vintage', 'retro', 'hàn quốc', 'tối giản', 'cổ điển', 'vô cực'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _tag;
  late final TextEditingController _capacity;
  late final TextEditingController _description;
  String? _newAvatarPath; // ảnh vừa chọn trên máy (chưa tải lên)
  List<String> _tags = _defaultTags;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _name = TextEditingController(text: s?.name ?? '');
    _tag = TextEditingController(text: s?.styleTag ?? '');
    _capacity = TextEditingController(text: '${s?.capacity ?? 4}');
    _description = TextEditingController(text: s?.description ?? '');
    context.read<OwnerStudiosProvider>().fetchStyleTags().then((fromServer) {
      if (!mounted) return;
      setState(() => _tags = {..._defaultTags, ...fromServer}.toList());
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _tag, _capacity, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final paths = await pickStudioImages(context, max: 1);
      if (paths.isNotEmpty && mounted) setState(() => _newAvatarPath = paths.first);
    } on StateError catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _newAvatarPath == null) {
      showToast(context, 'Chọn ảnh đại diện cho bối cảnh (ảnh này dùng cho tìm kiếm bằng ảnh)');
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<OwnerStudiosProvider>();
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        // Concept lưu chữ thường để lọc theo concept khớp nhau ("Vintage" = "vintage")
        // Bỏ trống -> null (không tạo concept rỗng trong danh sách concept)
        'style_tag': _tag.text.trim().isEmpty ? null : _tag.text.trim().toLowerCase(),
        'capacity': int.parse(_capacity.text.trim()),
        'description': _description.text.trim(),
      };
      if (_newAvatarPath != null) {
        body['avatar_url'] = await provider.uploadMedia(widget.studioId, _newAvatarPath!);
      }
      final warnings = _isEdit
          ? await provider.updateSet(widget.studioId, widget.initial!.id, body)
          : await provider.createSet(widget.studioId, body);
      if (!mounted) return;
      if (warnings.isNotEmpty) {
        showToast(context, 'Đã lưu. Chưa cập nhật được tìm kiếm bằng ảnh (dịch vụ AI chưa chạy).');
      }
      Navigator.of(context).pop(true);
    } on OwnerActionException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.initial?.avatarUrl ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa bối cảnh' : 'Thêm bối cảnh')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // ---- Ảnh đại diện ----
            GestureDetector(
              onTap: _saving ? null : _pickAvatar,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_newAvatarPath != null)
                        Image.file(File(_newAvatarPath!), fit: BoxFit.cover)
                      else if (existing.isNotEmpty)
                        Image.network(
                          existing,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(color: AppColors.surfaceMuted),
                        )
                      else
                        const ColoredBox(color: AppColors.surfacePink),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: const Color(0x99161018),
                          child: Text(
                            _newAvatarPath == null && existing.isEmpty
                                ? 'Chọn ảnh đại diện *'
                                : 'Đổi ảnh đại diện',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn ảnh chụp TOÀN CẢNH bối cảnh, không có người — ảnh này hiện trên thẻ bối cảnh '
              'và dùng cho tìm kiếm bằng hình ảnh. Ảnh chi tiết thêm vào album sau.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textFaint),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tên bối cảnh *',
                hintText: 'vd: Set Retro, Phòng phông trắng',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên bối cảnh' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tag,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Concept',
                hintText: 'vd: vintage',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _tags)
                  ChoiceChip(
                    label: Text(t),
                    selected: _tag.text.trim().toLowerCase() == t,
                    onSelected: (_) => setState(() => _tag.text = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            IntField(
              controller: _capacity,
              label: 'Sức chứa (người) *',
              min: 1,
              max: 100,
              helper: 'Số người tối đa chụp cùng lúc trong bối cảnh này',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                hintText: 'Diện tích, ánh sáng, đạo cụ, màu phông...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            SaveButton(
              label: _isEdit ? 'Lưu thay đổi' : 'Thêm bối cảnh',
              saving: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
