import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/owner_studio_model.dart';
import '../../providers/owner_studios_provider.dart';
import 'owner_set_detail_screen.dart';
import 'set_form_screen.dart';
import 'widgets/owner_ui.dart';

/// Danh sách bối cảnh của 1 studio (gồm cả bối cảnh đang ẩn).
class OwnerSetsScreen extends StatefulWidget {
  final String studioId;

  const OwnerSetsScreen({super.key, required this.studioId});

  @override
  State<OwnerSetsScreen> createState() => _OwnerSetsScreenState();
}

class _OwnerSetsScreenState extends State<OwnerSetsScreen> {
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

  Future<void> _add() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SetFormScreen(studioId: widget.studioId)),
    );
    if (ok == true && mounted) {
      showToast(context, 'Đã thêm bối cảnh. Thêm gói thuê để khách đặt được nhé!');
      await _load();
    }
  }

  Future<void> _open(OwnerSet set) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerSetDetailScreen(studioId: widget.studioId, setId: set.id),
      ),
    );
    if (mounted) _load(); // có thể đã sửa / ẩn / thêm gói
  }

  @override
  Widget build(BuildContext context) {
    final s = _studio;
    return Scaffold(
      appBar: AppBar(title: const Text('Bối cảnh & gói thuê')),
      floatingActionButton: s == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm bối cảnh'),
            ),
      body: s == null
          ? LoadState(error: _error, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  const HintBox(
                    'Mỗi bối cảnh là một không gian cho thuê có lịch riêng. Nhiều phông nền trong cùng '
                    'một phòng tính là MỘT bối cảnh. Khách chỉ đặt được bối cảnh đang hiện và có gói thuê.',
                  ),
                  const SizedBox(height: 16),
                  if (s.sets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text(
                        'Chưa có bối cảnh nào.\nBấm "Thêm bối cảnh" để bắt đầu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textBody),
                      ),
                    )
                  else
                    for (final set in s.sets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SetTile(set: set, onTap: () => _open(set)),
                      ),
                ],
              ),
            ),
    );
  }
}

class _SetTile extends StatelessWidget {
  final OwnerSet set;
  final VoidCallback onTap;

  const _SetTile({required this.set, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = set.activePackages;
    final String priceText;
    if (active.isEmpty) {
      priceText = 'Chưa có gói đang bán';
    } else {
      final cheapest = active.reduce((a, b) => a.price <= b.price ? a : b);
      priceText = 'Từ ${Formatters.vnd(cheapest.price)} · ${active.length} gói';
    }

    return Opacity(
      opacity: set.isActive ? 1 : 0.6,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: Image.network(
                      set.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const ColoredBox(
                        color: AppColors.surfacePink,
                        child: Icon(Icons.photo_camera_outlined, color: AppColors.accentText),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              set.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTitle,
                              ),
                            ),
                          ),
                          if (!set.isActive) ...[
                            const SizedBox(width: 6),
                            const MutedTag('Đang ẩn'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if ((set.styleTag ?? '').isNotEmpty) set.styleTag!,
                          '${set.capacity} người',
                          '${set.images.length + 1} ảnh',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active.isEmpty ? AppColors.statusWarning : AppColors.accentText,
                        ),
                      ),
                    ],
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
