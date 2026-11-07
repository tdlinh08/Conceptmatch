import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/owner_studio_model.dart';
import '../../providers/owner_studios_provider.dart';
import '../studios/widgets/photo_viewer.dart';
import 'studio_form_screen.dart';
import 'widgets/pick_images.dart';
import 'widgets/studio_status_badge.dart';

/// Quản lý 1 studio (phía chủ studio): trạng thái duyệt, ảnh studio, thông tin,
/// giờ mở cửa / phụ thu. Bối cảnh, gói thuê, nhân sự, dịch vụ thêm: bước 15b.
class OwnerStudioDetailScreen extends StatefulWidget {
  final String studioId;

  const OwnerStudioDetailScreen({super.key, required this.studioId});

  @override
  State<OwnerStudioDetailScreen> createState() => _OwnerStudioDetailScreenState();
}

class _OwnerStudioDetailScreenState extends State<OwnerStudioDetailScreen> {
  OwnerStudioDetail? _studio;
  String? _error;
  bool _busy = false; // đang tải ảnh / đổi ảnh bìa / xoá

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

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Chạy 1 thao tác ảnh: khoá màn, báo lỗi nếu có, tải lại chi tiết.
  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (success != null && mounted) _toast(success);
    } on OwnerActionException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addImages() async {
    final List<String> paths;
    try {
      paths = await pickStudioImages(context);
    } on StateError catch (e) {
      _toast(e.message);
      return;
    }
    if (paths.isEmpty || !mounted) return;
    final provider = context.read<OwnerStudiosProvider>();
    await _run(
      () => provider.uploadImages(widget.studioId, paths),
      success: 'Đã thêm ${paths.length} ảnh',
    );
  }

  Future<void> _imageActions(OwnerStudioImage image, int index) async {
    final images = _studio!.images;
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
              if (!image.isCover)
                ListTile(
                  leading: const Icon(Icons.star_outline_rounded),
                  title: const Text('Đặt làm ảnh bìa'),
                  onTap: () => Navigator.of(context).pop('cover'),
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
    final provider = context.read<OwnerStudiosProvider>();

    switch (action) {
      case 'view':
        PhotoViewerScreen.open(context, [for (final i in images) i.url], index: index);
      case 'cover':
        await _run(() => provider.setCover(widget.studioId, image.id), success: 'Đã đổi ảnh bìa');
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xoá ảnh này?'),
            content: Text(
              image.isCover
                  ? 'Đây là ảnh bìa. Xoá đi thì ảnh kế tiếp sẽ thành ảnh bìa.'
                  : 'Ảnh sẽ bị xoá khỏi studio.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.statusError),
                child: const Text('Xoá'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await _run(() => provider.deleteImage(widget.studioId, image.id), success: 'Đã xoá ảnh');
        }
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StudioFormScreen(initial: _studio)),
    );
    if (saved == true && mounted) {
      final wasRejected = _studio?.status == StudioStatus.rejected;
      await _load();
      _toast(wasRejected ? 'Đã lưu và gửi duyệt lại' : 'Đã lưu thay đổi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _studio;
    return Scaffold(
      appBar: AppBar(
        title: Text(s?.name ?? 'Studio'),
        actions: [
          if (s != null)
            IconButton(
              tooltip: 'Sửa thông tin',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : _edit,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (s == null)
            Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
                        ],
                      ),
                    ),
            )
          else
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  _StatusCard(studio: s),
                  const SizedBox(height: 24),
                  _Header(
                    'Ảnh studio',
                    trailing: '${s.images.length} ảnh',
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ảnh bìa hiện trên thẻ studio. Bấm vào ảnh để đặt làm bìa hoặc xoá.',
                    style: TextStyle(fontSize: 13, color: AppColors.textFaint),
                  ),
                  const SizedBox(height: 12),
                  _ImageGrid(
                    images: s.images,
                    onAdd: _busy ? null : _addImages,
                    onTapImage: _busy ? null : _imageActions,
                  ),
                  const SizedBox(height: 28),
                  _Header('Thông tin', action: 'Sửa', onAction: _busy ? null : _edit),
                  const SizedBox(height: 10),
                  _InfoCard(
                    rows: [
                      (Icons.place_outlined, '${s.address}, ${s.district}'),
                      (Icons.call_outlined, s.phone),
                      (
                        Icons.schedule_rounded,
                        s.isOpen24h ? 'Mở cửa 24/7' : 'Mở cửa ${s.openTime} – ${s.closeTime}',
                      ),
                      (
                        Icons.nightlight_outlined,
                        s.eveningSurchargePct > 0
                            ? 'Phụ thu +${s.eveningSurchargePct}% nếu bắt đầu từ ${s.eveningStartTime}'
                            : 'Không phụ thu giờ tối',
                      ),
                      (
                        Icons.weekend_outlined,
                        s.weekendSurchargePct > 0
                            ? 'Phụ thu +${s.weekendSurchargePct}% thứ 7, chủ nhật'
                            : 'Không phụ thu cuối tuần',
                      ),
                    ],
                  ),
                  if ((s.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      s.description!.trim(),
                      style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textBody),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const _Header('Bối cảnh & dịch vụ'),
                  const SizedBox(height: 10),
                  _ComingRow(
                    icon: Icons.chair_outlined,
                    title: 'Bối cảnh & gói thuê',
                    value: '${s.setCount} bối cảnh',
                  ),
                  _ComingRow(
                    icon: Icons.badge_outlined,
                    title: 'Nhân sự (thợ ảnh, trang điểm)',
                    value: '${s.staffCount} người',
                  ),
                  _ComingRow(
                    icon: Icons.add_business_outlined,
                    title: 'Dịch vụ thêm',
                    value: '${s.addonCount} dịch vụ',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Quản lý bối cảnh, gói thuê, nhân sự và dịch vụ ngay trong app sẽ có ở bản cập nhật tiếp theo.',
                    style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thẻ trạng thái duyệt + việc cần làm tiếp.
class _StatusCard extends StatelessWidget {
  final OwnerStudioDetail studio;

  const _StatusCard({required this.studio});

  @override
  Widget build(BuildContext context) {
    final s = studio;
    final String message;
    switch (s.status) {
      case StudioStatus.active:
        message = 'Studio đang hiển thị với khách và nhận đặt lịch.';
      case StudioStatus.rejected:
        message = 'Lý do: ${s.rejectReason ?? 'không ghi'}.\n'
            'Sửa lại thông tin rồi lưu — studio sẽ tự gửi duyệt lại.';
      default:
        message = 'Quản trị viên sẽ duyệt studio trước khi khách nhìn thấy.';
    }

    final showChecklist = s.status != StudioStatus.active;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioStatusBadge(status: s.status),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: s.status == StudioStatus.rejected ? AppColors.statusError : AppColors.textBody,
            ),
          ),
          if (showChecklist) ...[
            const SizedBox(height: 12),
            const Text(
              'Chuẩn bị để được duyệt',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textTitle),
            ),
            const SizedBox(height: 6),
            const _Check(done: true, text: 'Thông tin studio, giờ mở cửa'),
            _Check(done: s.images.isNotEmpty, text: 'Ít nhất 1 ảnh studio (nên có 3–5 ảnh)'),
            _Check(
              done: s.readyForApproval,
              text: 'Ít nhất 1 bối cảnh có gói thuê đang bán (bắt buộc)',
            ),
          ],
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool done;
  final String text;

  const _Check({required this.done, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: done ? AppColors.statusSuccess : AppColors.textFaint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  final String? trailing;
  final String? action;
  final VoidCallback? onAction;

  const _Header(this.text, {this.trailing, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.textTitle,
            ),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(fontSize: 13, color: AppColors.textFaint)),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

/// Lưới ảnh 3 cột, ô đầu là nút "Thêm ảnh"; ảnh bìa có nhãn.
class _ImageGrid extends StatelessWidget {
  final List<OwnerStudioImage> images;
  final VoidCallback? onAdd;
  final void Function(OwnerStudioImage image, int index)? onTapImage;

  const _ImageGrid({required this.images, required this.onAdd, required this.onTapImage});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: images.length + 1,
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
              onTap: onAdd,
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
        final image = images[i - 1];
        return GestureDetector(
          onTap: onTapImage == null ? null : () => onTapImage!(image, i - 1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: AppColors.surfaceMuted),
                ),
                if (image.isCover)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Ảnh bìa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<(IconData, String)> rows;

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          for (final (icon, text) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: AppColors.textFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textBody),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Mục sẽ quản lý ở bước 15b — tạm hiện số lượng.
class _ComingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ComingRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textTitle)),
          ),
          Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textFaint)),
        ],
      ),
    );
  }
}
