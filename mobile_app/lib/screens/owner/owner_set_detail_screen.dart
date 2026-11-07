import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/owner_studio_model.dart';
import '../../providers/owner_studios_provider.dart';
import '../studios/widgets/photo_viewer.dart';
import 'package_form_screen.dart';
import 'set_form_screen.dart';
import 'widgets/owner_ui.dart';
import 'widgets/pick_images.dart';

/// Quản lý 1 bối cảnh: ảnh đại diện + album, thông tin, ẩn/hiện, các gói thuê.
class OwnerSetDetailScreen extends StatefulWidget {
  final String studioId;
  final String setId;

  const OwnerSetDetailScreen({super.key, required this.studioId, required this.setId});

  @override
  State<OwnerSetDetailScreen> createState() => _OwnerSetDetailScreenState();
}

class _OwnerSetDetailScreenState extends State<OwnerSetDetailScreen> {
  static const _maxAlbum = 10;

  OwnerStudioDetail? _studio;
  String? _error;
  bool _busy = false;

  OwnerSet? get _set => _studio?.setById(widget.setId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await context.read<OwnerStudiosProvider>().fetchDetail(widget.studioId);
      if (!mounted) return;
      setState(() {
        _studio = s;
        if (s.setById(widget.setId) == null) _error = 'Bối cảnh không còn tồn tại';
      });
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Chạy 1 thao tác: khoá màn, báo lỗi nếu có, tải lại.
  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (success != null && mounted) showToast(context, success);
    } on OwnerActionException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SetFormScreen(studioId: widget.studioId, initial: _set)),
    );
    if (ok == true && mounted) {
      await _load();
      if (mounted) showToast(context, 'Đã lưu bối cảnh');
    }
  }

  Future<void> _toggleActive(bool show) async {
    final set = _set!;
    if (!show) {
      final ok = await confirmAction(
        context,
        title: 'Ẩn bối cảnh?',
        message: 'Khách sẽ không thấy và không đặt được "${set.name}". '
            'Các đơn đã đặt vẫn giữ nguyên. Bạn có thể hiện lại bất cứ lúc nào.',
        confirmLabel: 'Ẩn',
      );
      if (!ok || !mounted) return;
    }
    final provider = context.read<OwnerStudiosProvider>();
    await _run(
      () => provider.updateSet(widget.studioId, set.id, {'is_active': show}),
      success: show ? 'Đã hiện bối cảnh' : 'Đã ẩn bối cảnh',
    );
  }

  Future<void> _addAlbum() async {
    final remaining = _maxAlbum - _set!.images.length;
    if (remaining <= 0) {
      showToast(context, 'Album đã đủ $_maxAlbum ảnh. Xoá bớt ảnh để thêm ảnh mới.');
      return;
    }
    final List<String> paths;
    try {
      paths = await pickStudioImages(context, max: remaining);
    } on StateError catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    if (paths.isEmpty || !mounted) return;
    final provider = context.read<OwnerStudiosProvider>();
    await _run(
      () => provider.addSetImages(widget.studioId, widget.setId, paths),
      success: 'Đã thêm ${paths.length} ảnh',
    );
  }

  Future<void> _albumImageActions(OwnerSetImage image, List<String> gallery, int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.fullscreen_rounded),
                title: const Text('Xem ảnh'),
                onTap: () => Navigator.of(context).pop('view'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.statusError),
                title: const Text('Xoá ảnh', style: TextStyle(color: AppColors.statusError)),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'view') {
      PhotoViewerScreen.open(context, gallery, index: index, title: _set?.name);
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Xoá ảnh này?',
      message: 'Ảnh sẽ bị xoá khỏi album bối cảnh.',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final provider = context.read<OwnerStudiosProvider>();
    await _run(
      () => provider.deleteSetImage(widget.studioId, widget.setId, image.id),
      success: 'Đã xoá ảnh',
    );
  }

  Future<void> _openPackage([OwnerPackage? pkg]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PackageFormScreen(
          studioId: widget.studioId,
          set: _set!,
          openMinutes: _studio!.openMinutes,
          initial: pkg,
        ),
      ),
    );
    if (ok == true && mounted) {
      await _load();
      if (mounted) showToast(context, pkg == null ? 'Đã thêm gói thuê' : 'Đã lưu gói thuê');
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = _set;
    return Scaffold(
      appBar: AppBar(
        title: Text(set?.name ?? 'Bối cảnh'),
        actions: [
          if (set != null)
            IconButton(
              tooltip: 'Sửa bối cảnh',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : _edit,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (set == null)
            LoadState(error: _error, onRetry: _load)
          else
            RefreshIndicator(onRefresh: _load, child: _buildBody(set)),
          if (_busy) const BusyOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody(OwnerSet set) {
    // Ảnh xem toàn màn hình: ảnh đại diện + album (giống thứ tự khách thấy)
    final gallery = [set.avatarUrl, ...set.images.map((i) => i.url)];
    final tag = set.styleTag ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        GestureDetector(
          onTap: () => PhotoViewerScreen.open(context, gallery, title: set.name),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                set.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: AppColors.surfacePink,
                  child: Center(
                    child: Text(
                      'Ảnh đại diện lỗi — bấm bút để đổi ảnh',
                      style: TextStyle(color: AppColors.accentText),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          [if (tag.isNotEmpty) 'Concept: $tag', 'Sức chứa ${set.capacity} người'].join(' · '),
          style: const TextStyle(fontSize: 14, color: AppColors.textBody),
        ),
        if ((set.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            set.description!.trim(),
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hiện với khách'),
          subtitle: Text(set.isActive ? 'Khách thấy và đặt được' : 'Đang ẩn — khách không thấy'),
          value: set.isActive,
          onChanged: _busy ? null : _toggleActive,
        ),
        if (set.isActive && !set.isBookable)
          const HintBox(
            'Bối cảnh chưa có gói thuê đang bán nên khách chưa đặt được. Thêm gói thuê ở dưới.',
            warning: true,
          ),

        // ---- Album ----
        const SizedBox(height: 20),
        OwnerSectionHeader('Album ảnh', trailing: '${set.images.length}/$_maxAlbum ảnh'),
        const SizedBox(height: 4),
        const Text(
          'Ảnh chi tiết góc chụp, đạo cụ, ảnh mẫu — khách xem ở màn chi tiết bối cảnh.',
          style: TextStyle(fontSize: 13, color: AppColors.textFaint),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: set.images.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Material(
                color: AppColors.surfacePink,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _busy ? null : _addAlbum,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppColors.accentText),
                      SizedBox(height: 4),
                      Text(
                        'Thêm ảnh',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final image = set.images[i - 1];
            return GestureDetector(
              onTap: _busy ? null : () => _albumImageActions(image, gallery, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: AppColors.surfaceMuted),
                ),
              ),
            );
          },
        ),

        // ---- Gói thuê ----
        const SizedBox(height: 24),
        OwnerSectionHeader(
          'Gói thuê',
          action: 'Thêm gói',
          onAction: _busy ? null : () => _openPackage(),
        ),
        const SizedBox(height: 6),
        if (set.packages.isEmpty)
          const Text(
            'Chưa có gói nào. Ví dụ: "Gói 1 giờ" 300.000đ gồm 2 người, "Nửa ngày" 4 giờ...',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
          )
        else
          for (final p in set.packages)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PackageTile(package: p, onTap: _busy ? null : () => _openPackage(p)),
            ),
      ],
    );
  }
}

class _PackageTile extends StatelessWidget {
  final OwnerPackage package;
  final VoidCallback? onTap;

  const _PackageTile({required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = package;
    final people = p.extraPersonFee > 0
        ? 'Gồm ${p.includedPeople} người · +${Formatters.vnd(p.extraPersonFee)}/người thêm · tối đa ${p.maxPeople}'
        : 'Tối đa ${p.maxPeople} người';
    return Opacity(
      opacity: p.isActive ? 1 : 0.6,
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTitle,
                              ),
                            ),
                          ),
                          if (!p.isActive) ...[
                            const SizedBox(width: 6),
                            const MutedTag('Đang ẩn'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.duration(p.durationMinutes),
                        style: const TextStyle(fontSize: 13, color: AppColors.accentText),
                      ),
                      const SizedBox(height: 2),
                      Text(people, style: const TextStyle(fontSize: 12, color: AppColors.textBody)),
                    ],
                  ),
                ),
                Text(
                  Formatters.vnd(p.price),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTitle,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
