import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin_models.dart';
import '../../models/owner_studio_model.dart';
import '../../models/studio_detail_model.dart' show StaffRoles;
import '../../providers/admin_provider.dart';
import '../../providers/owner_studios_provider.dart' show OwnerActionException;
import '../map/studio_mini_map.dart';
import '../owner/widgets/studio_status_badge.dart';
import '../studios/widgets/photo_viewer.dart';
import 'admin_ui.dart';

/// Hồ sơ 1 studio để admin xem xét: ảnh, thông tin, vị trí, bối cảnh + gói, nhân sự, dịch vụ.
/// Chờ duyệt -> Duyệt / Từ chối; Đang hoạt động -> Gỡ khỏi sàn. pop(true) nếu có thay đổi.
class AdminStudioDetailScreen extends StatefulWidget {
  final String studioId;

  const AdminStudioDetailScreen({super.key, required this.studioId});

  @override
  State<AdminStudioDetailScreen> createState() => _AdminStudioDetailScreenState();
}

class _AdminStudioDetailScreenState extends State<AdminStudioDetailScreen> {
  AdminStudioDetail? _d;
  String? _error;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await context.read<AdminProvider>().studio(widget.studioId);
      if (mounted) setState(() => _d = d);
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
      await _load();
      if (mounted) _toast(success);
    } on OwnerActionException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duyệt studio?'),
        content: Text(
          '"${_d!.studio.name}" sẽ hiển thị với khách và nhận đặt lịch. '
          'Ảnh bối cảnh sẽ được đưa vào tìm kiếm bằng hình ảnh.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Duyệt')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final provider = context.read<AdminProvider>();
    await _run(() async {
      final warnings = await provider.approve(widget.studioId);
      if (warnings.isNotEmpty && mounted) {
        _toast('Đã duyệt. Chưa tạo được dữ liệu tìm kiếm bằng ảnh (dịch vụ AI chưa chạy).');
      }
    }, 'Đã duyệt studio');
  }

  Future<void> _reject() async {
    final reason = await askReason(
      context,
      title: 'Từ chối hồ sơ studio',
      hint: 'Chủ studio sẽ thấy lý do này để sửa',
      confirmLabel: 'Từ chối',
      quick: const [
        'Ảnh studio chưa rõ / chưa đủ',
        'Thông tin liên hệ chưa chính xác',
        'Giá gói thuê chưa hợp lý',
        'Chưa ghim vị trí trên bản đồ',
      ],
    );
    if (reason == null || !mounted) return;
    final provider = context.read<AdminProvider>();
    await _run(() => provider.reject(widget.studioId, reason), 'Đã từ chối hồ sơ');
  }

  Future<void> _takeDown() async {
    final reason = await askReason(
      context,
      title: 'Gỡ studio khỏi sàn',
      hint: 'Khách sẽ không thấy studio; chủ studio sửa lại để gửi duyệt lại',
      confirmLabel: 'Gỡ studio',
      quick: const [
        'Thông tin sai sự thật',
        'Nhiều phản ánh từ khách hàng',
        'Studio ngừng hoạt động',
      ],
    );
    if (reason == null || !mounted) return;
    final provider = context.read<AdminProvider>();
    await _run(() => provider.takeDown(widget.studioId, reason), 'Đã gỡ studio');
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed); // báo trang danh sách tải lại
      },
      child: Scaffold(
        appBar: AppBar(title: Text(d?.studio.name ?? 'Hồ sơ studio')),
        body: Stack(
          children: [
            if (d == null)
              Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
                        ],
                      ),
              )
            else
              _buildBody(d),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        bottomNavigationBar: d == null ? null : _buildActions(d.studio),
      ),
    );
  }

  Widget? _buildActions(OwnerStudioDetail s) {
    final List<Widget> buttons;
    switch (s.status) {
      case StudioStatus.pending:
        buttons = [
          OutlinedButton(onPressed: _busy ? null : _reject, child: const Text('Từ chối')),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _busy || !s.readyForApproval ? null : _approve,
            child: const Text('Duyệt studio'),
          ),
        ];
      case StudioStatus.active:
        buttons = [
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.statusError),
            onPressed: _busy ? null : _takeDown,
            child: const Text('Gỡ khỏi sàn'),
          ),
        ];
      default:
        return null;
    }
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: buttons),
        ),
      ),
    );
  }

  Widget _buildBody(AdminStudioDetail d) {
    final s = d.studio;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- Trạng thái + kiểm tra nhanh ----
                AdminCard(
                  children: [
                    Row(
                      children: [
                        StudioStatusBadge(status: s.status),
                        const Spacer(),
                        if (d.createdAt != null)
                          Text(
                            'Tạo ngày ${fmtDate(d.createdAt!)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                          ),
                      ],
                    ),
                    if (s.status == StudioStatus.rejected && (s.rejectReason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Lý do: ${s.rejectReason}', style: const TextStyle(color: AppColors.statusError)),
                    ],
                    if (s.status == StudioStatus.pending) ...[
                      const SizedBox(height: 12),
                      _Check(s.images.isNotEmpty, 'Có ảnh studio (${s.images.length} ảnh)'),
                      _Check(s.readyForApproval,
                          'Có bối cảnh đang bán gói thuê (${s.bookableSetCount}/${s.setCount}) — bắt buộc'),
                      _Check(s.hasLocation, 'Đã ghim vị trí trên bản đồ'),
                      _Check(s.staffCount > 0 || s.addonCount == 0,
                          'Dịch vụ thêm có người phụ trách (${s.staffCount} nhân sự)'),
                      if (!s.readyForApproval)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Chưa đủ điều kiện duyệt: cần ít nhất 1 bối cảnh có gói thuê đang bán.',
                            style: TextStyle(fontSize: 13, color: AppColors.statusWarning),
                          ),
                        ),
                    ],
                  ],
                ),

                // ---- Chủ studio + thông tin ----
                AdminCard(
                  title: 'Thông tin',
                  children: [
                    _Info(Icons.person_outline_rounded,
                        'Chủ studio: ${d.ownerName} · ${d.ownerEmail}${d.ownerStatus == 'locked' ? ' (đang bị khoá)' : ''}'),
                    _Info(Icons.place_outlined, '${s.address}, ${s.district}'),
                    _Info(Icons.call_outlined, s.phone),
                    _Info(Icons.schedule_rounded,
                        s.isOpen24h ? 'Mở cửa 24/7' : 'Mở cửa ${s.openTime} – ${s.closeTime}'),
                    _Info(
                      Icons.percent_rounded,
                      'Phụ thu: giờ tối từ ${s.eveningStartTime} +${s.eveningSurchargePct}% · cuối tuần +${s.weekendSurchargePct}%',
                    ),
                    if ((s.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(s.description!.trim(),
                          style: const TextStyle(height: 1.5, color: AppColors.textBody)),
                    ],
                    if (s.hasLocation) ...[
                      const SizedBox(height: 12),
                      StudioMiniMap(latitude: s.latitude!, longitude: s.longitude!, height: 200),
                    ],
                  ],
                ),

                // ---- Ảnh studio ----
                AdminCard(
                  title: 'Ảnh studio (${s.images.length})',
                  children: [
                    if (s.images.isEmpty)
                      const Text('Chưa có ảnh.', style: TextStyle(color: AppColors.textBody))
                    else
                      _Thumbs(urls: [for (final i in s.images) i.url], title: s.name),
                  ],
                ),

                // ---- Bối cảnh + gói ----
                AdminCard(
                  title: 'Bối cảnh & gói thuê (${s.setCount})',
                  children: [
                    if (s.sets.isEmpty)
                      const Text('Chưa có bối cảnh.', style: TextStyle(color: AppColors.textBody)),
                    for (final set in s.sets) _SetBlock(set: set),
                  ],
                ),

                // ---- Nhân sự + dịch vụ ----
                AdminCard(
                  title: 'Nhân sự & dịch vụ thêm',
                  children: [
                    Text(
                      'Thợ ảnh: ${s.activeStaffOf(StaffRoles.photographer)} · '
                      'Trang điểm: ${s.activeStaffOf(StaffRoles.makeup)} (đang làm)',
                      style: const TextStyle(color: AppColors.textBody),
                    ),
                    const SizedBox(height: 8),
                    if (s.addons.isEmpty)
                      const Text('Không bán dịch vụ thêm.', style: TextStyle(color: AppColors.textBody))
                    else
                      for (final a in s.addons)
                        _Info(
                          a.role == StaffRoles.makeup ? Icons.brush_outlined : Icons.photo_camera_outlined,
                          '${a.name} — ${Formatters.vnd(a.price)} '
                          '${switch (a.unit) { 'per_hour' => '/giờ', 'per_person' => '/người', _ => '/lượt' }}'
                          '${a.isActive ? '' : ' (đang ẩn)'}',
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  final bool done;
  final String text;
  const _Check(this.done, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: done ? AppColors.statusSuccess : AppColors.textFaint,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textBody))),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textFaint),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textBody))),
        ],
      ),
    );
  }
}

/// Dãy ảnh nhỏ, bấm để xem toàn màn hình.
class _Thumbs extends StatelessWidget {
  final List<String> urls;
  final String title;
  final double size;
  const _Thumbs({required this.urls, required this.title, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < urls.length; i++)
          GestureDetector(
            onTap: () => PhotoViewerScreen.open(context, urls, index: i, title: title),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: size,
                height: size,
                child: Image.network(
                  urls[i],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: AppColors.surfaceMuted),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SetBlock extends StatelessWidget {
  final OwnerSet set;
  const _SetBlock({required this.set});

  @override
  Widget build(BuildContext context) {
    final photos = [set.avatarUrl, ...set.images.map((i) => i.url)];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: set.isActive ? AppColors.background : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              set.name,
              if ((set.styleTag ?? '').isNotEmpty) set.styleTag!,
              '${set.capacity} người',
              if (!set.isActive) 'đang ẩn',
            ].join(' · '),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textTitle),
          ),
          const SizedBox(height: 8),
          _Thumbs(urls: photos, title: set.name, size: 72),
          const SizedBox(height: 8),
          if (set.packages.isEmpty)
            const Text('Chưa có gói thuê', style: TextStyle(fontSize: 13, color: AppColors.statusWarning))
          else
            for (final p in set.packages)
              Text(
                '• ${p.name}: ${Formatters.duration(p.durationMinutes)} · ${Formatters.vnd(p.price)} '
                '(gồm ${p.includedPeople}, tối đa ${p.maxPeople} người'
                '${p.extraPersonFee > 0 ? ', +${Formatters.vnd(p.extraPersonFee)}/người thêm' : ''})'
                '${p.isActive ? '' : ' — đang ẩn'}',
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textBody),
              ),
        ],
      ),
    );
  }
}
