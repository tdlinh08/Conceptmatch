import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/owner_studio_model.dart';
import '../../providers/owner_studios_provider.dart';
import 'owner_studio_detail_screen.dart';
import 'studio_form_screen.dart';
import 'widgets/studio_status_badge.dart';

/// Tab "Studio" của chủ studio: danh sách studio của tôi (mọi trạng thái) + tạo mới.
class MyStudiosScreen extends StatelessWidget {
  const MyStudiosScreen({super.key});

  static Future<void> createStudio(BuildContext context) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const StudioFormScreen()),
    );
    if (id == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã tạo studio. Thêm ảnh để studio hấp dẫn hơn nhé!')),
    );
    // Mở luôn studio vừa tạo để thêm ảnh
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OwnerStudioDetailScreen(studioId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OwnerStudiosProvider>();
    final studios = provider.studios;

    return Scaffold(
      floatingActionButton: studios.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => createStudio(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo studio'),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.fetchMine,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            children: [
              const Text(
                'Studio của tôi',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 16),
              if (provider.isLoading && !provider.loaded)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.errorMessage != null && studios.isEmpty)
                _Message(
                  icon: Icons.wifi_off_rounded,
                  text: provider.errorMessage!,
                  actionLabel: 'Thử lại',
                  onAction: provider.fetchMine,
                )
              else if (studios.isEmpty)
                _Message(
                  icon: Icons.storefront_outlined,
                  text: 'Bạn chưa có studio nào.\nTạo studio đầu tiên để bắt đầu nhận lịch đặt.',
                  actionLabel: 'Tạo studio',
                  onAction: () => createStudio(context),
                )
              else
                for (final s in studios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _StudioTile(
                      studio: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OwnerStudioDetailScreen(studioId: s.id),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioTile extends StatelessWidget {
  final OwnerStudioSummary studio;
  final VoidCallback onTap;

  const _StudioTile({required this.studio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = studio;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 7,
              child: s.coverImage == null
                  ? const _CoverPlaceholder()
                  : Image.network(
                      s.coverImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const _CoverPlaceholder(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTitle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StudioStatusBadge(status: s.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.address} · ${s.district}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                  ),
                  if (s.status == StudioStatus.rejected && (s.rejectReason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Lý do: ${s.rejectReason}',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.statusError,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _Stat(icon: Icons.photo_outlined, text: '${s.imageCount} ảnh'),
                      _Stat(icon: Icons.chair_outlined, text: '${s.setCount} bối cảnh'),
                      if (s.status == StudioStatus.active)
                        _Stat(
                          icon: Icons.star_rounded,
                          text: s.reviewCount == 0
                              ? 'Chưa có đánh giá'
                              : '${s.avgRating.toStringAsFixed(1)} (${s.reviewCount})',
                        ),
                      if (s.pendingBookingCount > 0)
                        _Stat(
                          icon: Icons.notifications_active_outlined,
                          text: '${s.pendingBookingCount} đơn chờ xác nhận',
                          highlight: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _Stat({required this.icon, required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.accentText : AppColors.textFaint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            color: highlight ? AppColors.accentText : AppColors.textBody,
          ),
        ),
      ],
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFEAD7DF), Color(0xFFA48AA3)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 30, color: Color(0xCCFFFFFF)),
            SizedBox(height: 4),
            Text('Chưa có ảnh bìa', style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF))),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textBody),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
