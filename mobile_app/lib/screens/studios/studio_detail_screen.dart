import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/studios_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../models/studio_detail_model.dart';
import '../../models/review_model.dart';
import '../../models/studio_model.dart';

class StudioDetailScreen extends StatefulWidget {
  final String studioId;

  const StudioDetailScreen({super.key, required this.studioId});

  @override
  State<StudioDetailScreen> createState() => _StudioDetailScreenState();
}

class _StudioDetailScreenState extends State<StudioDetailScreen> {
  static const double _heroHeight = 440;
  static const double _sheetOverlap = 28; // phần sheet trắng đè lên ảnh

  StudioDetailModel? _detail;
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;
  bool _hasError = false;

  String? _selectedSetId; // set đang chọn — sẽ truyền sang màn Đặt lịch
  int _imageIndex = 0;

  final _scrollController = ScrollController();
  bool _pastHero = false; // đã cuộn qua ảnh -> đổi icon thanh trạng thái sang màu tối

  @override
  void initState() {
    super.initState();
    _load();
    context.read<StudiosProvider>().recordView(widget.studioId);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final past = _scrollController.offset > _heroHeight - _sheetOverlap - 80;
    if (past != _pastHero) setState(() => _pastHero = past);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final provider = context.read<StudiosProvider>();
    final detail = await provider.fetchStudioDetail(widget.studioId);
    final reviews = await provider.fetchReviews(widget.studioId);

    if (!mounted) return;
    setState(() {
      _detail = detail;
      _reviews = reviews;
      _isLoading = false;
      _hasError = detail == null;
      if (detail != null && detail.sets.isNotEmpty) {
        _selectedSetId ??= detail.sets.first.id;
      }
    });
  }

  void _onChooseSchedule() {
    // Màn Đặt lịch sẽ làm ở bước sau — khi đó truyền detail + _selectedSetId sang.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Màn chọn lịch sẽ có ở bước tiếp theo')),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hasError || _detail == null) return _buildError();

    final detail = _detail!;
    final isFavorited = context.watch<FavoritesProvider>().isFavorited(detail.id);
    final topInset = MediaQuery.paddingOf(context).top;

    // Ảnh tối ở đầu màn -> icon thanh trạng thái màu SÁNG; cuộn qua ảnh -> màu TỐI.
    final overlayStyle = _pastHero
        ? AppTheme.systemOverlay
        : AppTheme.systemOverlay.copyWith(
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
                            slivers: [
                // Ảnh và sheet chung 1 Stack: sheet đặt SAU nên vẽ đè lên 28px
                // cuối của ảnh (bo góc hiện ra). Tách thành 2 sliver thì sliver
                // đứng trước (ảnh) lại vẽ đè lên sliver đứng sau (sheet).
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      _buildHero(detail),
                      Padding(
                        padding: const EdgeInsets.only(top: _heroHeight - _sheetOverlap),
                        child: _buildSheet(detail),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Thanh trên cùng: trong suốt khi đang ở ảnh, hiện nền trắng + tên
            // studio khi đã cuộn xuống (để nội dung không chạy lẫn dưới nút).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _pastHero ? 1 : 0,
                  child: Container(
                    height: topInset + 60,
                    padding: EdgeInsets.fromLTRB(72, topInset, 72, 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: const Border(bottom: BorderSide(color: AppColors.outline)),
                    ),
                    child: Text(
                      detail.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Nút quay lại + lưu: cố định ở trên cùng, nổi trên ảnh.
            Positioned(
              top: topInset + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: 'Quay lại',
                    onSurface: _pastHero,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  _GlassIconButton(
                    icon: isFavorited ? Icons.favorite : Icons.favorite_border,
                    tooltip: isFavorited ? 'Bỏ lưu studio' : 'Lưu studio',
                    onSurface: _pastHero,
                    highlighted: isFavorited,
                    onPressed: () =>
                        context.read<FavoritesProvider>().toggleFavorite(_toSummary(detail)),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(detail),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.textFaint, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Không tải được thông tin studio',
                style: TextStyle(color: AppColors.textBody, fontSize: 15),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 1. Ảnh lớn đầu trang, vuốt ngang để xem các ảnh ----
  Widget _buildHero(StudioDetailModel detail) {
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (detail.images.isEmpty)
            const _HeroPlaceholder()
          else
            PageView.builder(
              itemCount: detail.images.length,
              onPageChanged: (i) => setState(() => _imageIndex = i),
              itemBuilder: (context, index) => Image.network(
                detail.images[index].url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const _HeroPlaceholder(),
                errorBuilder: (context, error, stackTrace) => const _HeroPlaceholder(),
              ),
            ),

          // Dải tối mờ phía trên để nút và thanh trạng thái luôn đọc được.
          const IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x73161018), Color(0x00161018)],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Chấm chỉ số ảnh (chỉ hiện khi có từ 2 ảnh).
          if (detail.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: _sheetOverlap + 16,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(detail.images.length, (i) {
                    final active = i == _imageIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: active ? 1 : 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- 2. Sheet nội dung (bo góc trên, đè lên ảnh) ----
  Widget _buildSheet(StudioDetailModel detail) {
    final styleTags = detail.sets
        .map((s) => s.styleTag)
        .whereType<String>()
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetOverlap)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (styleTags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < styleTags.length; i++)
                  _TagPill(label: _capitalize(styleTags[i]), primary: i == 0),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Text(
            detail.name,
            style: const TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.location_on_outlined,
            child: Text(
              _fullAddress(detail),
              style: const TextStyle(fontSize: 14, color: AppColors.textBody, height: 1.4),
            ),
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.star_rounded,
            iconColor: AppColors.ratingGold,
            child: detail.reviewCount == 0
                ? const Text(
                    'Chưa có đánh giá',
                    style: TextStyle(fontSize: 14, color: AppColors.textBody),
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: detail.avgRating.toStringAsFixed(1).replaceAll('.', ','),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTitle,
                          ),
                        ),
                        TextSpan(text: '  ·  ${detail.reviewCount} đánh giá'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, color: AppColors.textBody),
                  ),
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.call_outlined,
            child: Text(
              detail.phone,
              style: const TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
          ),

          const _Divider(),

          if (detail.sets.isNotEmpty) ...[
            _SectionTitle(
              'Bối cảnh',
              trailing: '${detail.sets.length} set chụp',
            ),
            const SizedBox(height: 12),
            _buildSetList(detail.sets),
            const SizedBox(height: 8),
          ],

          if (detail.description != null && detail.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('Giới thiệu'),
            const SizedBox(height: 10),
            Text(
              detail.description!.trim(),
              style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textBody),
            ),
          ],

          if (detail.pricingRules.isNotEmpty) ...[
            const SizedBox(height: 28),
            const _SectionTitle('Bảng giá'),
            const SizedBox(height: 12),
            _PricingTable(rules: detail.pricingRules),
          ],

          const SizedBox(height: 28),
          _SectionTitle(
            'Đánh giá',
            trailing: detail.reviewCount > 0 ? '${detail.reviewCount} lượt' : null,
          ),
          const SizedBox(height: 12),
          if (_reviews.isEmpty)
            const Text(
              'Chưa có đánh giá nào. Đặt lịch và trải nghiệm để là người đầu tiên đánh giá.',
              style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
            )
          else
            ..._reviews.map((r) => _ReviewCard(review: r)),
        ],
      ),
    );
  }

  Widget _buildSetList(List<StudioSetModel> sets) {
    return SizedBox(
      height: 174,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: sets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final set = sets[index];
          return _SetCard(
            set: set,
            selected: set.id == _selectedSetId,
            onTap: () => setState(() => _selectedSetId = set.id),
          );
        },
      ),
    );
  }

  // ---- 3. Thanh dưới cố định: giá từ + nút Chọn lịch ----
  Widget _buildBottomBar(StudioDetailModel detail) {
    final minPrice = detail.pricingRules.isEmpty
        ? null
        : detail.pricingRules.map((r) => r.pricePerHour).reduce((a, b) => a < b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: minPrice == null
                    ? const Text(
                        'Liên hệ studio để biết giá',
                        style: TextStyle(fontSize: 14, color: AppColors.textBody),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Giá từ',
                            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: Formatters.vnd(minPrice),
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    color: AppColors.textTitle,
                                  ),
                                ),
                                const TextSpan(text: ' / giờ'),
                              ],
                            ),
                            style: const TextStyle(fontSize: 14, color: AppColors.textBody),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: detail.sets.isEmpty ? null : _onChooseSchedule,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Chọn lịch'),
                    SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Tiện ích ----

  StudioModel _toSummary(StudioDetailModel detail) {
    final prices = detail.pricingRules.map((r) => r.pricePerHour);
    return StudioModel(
      id: detail.id,
      name: detail.name,
      district: detail.district,
      avgRating: detail.avgRating,
      coverImage: detail.images.isEmpty
          ? null
          : detail.images.firstWhere((i) => i.isCover, orElse: () => detail.images.first).url,
      minPrice: prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b),
    );
  }

  /// Địa chỉ đã có tên quận (vd "123 Đường Láng, Đống Đa") thì không ghép thêm lần nữa.
  static String _fullAddress(StudioDetailModel d) {
    final address = d.address.trim();
    if (address.toLowerCase().contains(d.district.trim().toLowerCase())) return address;
    return '$address, ${d.district}';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// =============================================================================
// Widget con dùng riêng cho màn Chi tiết
// =============================================================================

/// Nút tròn trên ảnh: nền tối mờ khi nằm trên ảnh, nền trắng viền mảnh khi đã
/// cuộn xuống phần nội dung sáng ([onSurface] = true).
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool onSurface;
  final bool highlighted;

  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.onSurface,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (highlighted) {
      background = AppColors.primary;
      foreground = AppColors.onPrimary;
    } else if (onSurface) {
      background = AppColors.surface;
      foreground = AppColors.textTitle;
    } else {
      background = const Color(0x8C1A1320); // tối mờ 55%
      foreground = Colors.white;
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: CircleBorder(
          side: onSurface && !highlighted
              ? const BorderSide(color: AppColors.outline)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE6CFD9), Color(0xFF8E7590)],
        ),
      ),
      child: Center(
        child: Icon(Icons.photo_camera_outlined, size: 44, color: Color(0xB3FFFFFF)),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final bool primary;

  const _TagPill({required this.label, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: primary ? AppColors.surfacePink : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      // widthFactor: 1 -> nhãn chỉ rộng vừa chữ. (Bản trước dùng
      // Container(alignment: ...) khiến nhãn giãn ra hết chiều ngang màn hình.)
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
            color: primary ? AppColors.accentText : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _InfoRow({
    required this.icon,
    required this.child,
    this.iconColor = AppColors.textFaint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(height: 1, thickness: 1, color: AppColors.outline),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.textTitle,
            ),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
      ],
    );
  }
}

/// Thẻ một set chụp; set đang chọn có viền hồng trầm 2px.
class _SetCard extends StatelessWidget {
  final StudioSetModel set;
  final bool selected;
  final VoidCallback onTap;

  const _SetCard({required this.set, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${set.name}, tối đa ${set.capacity} người',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 120,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.accentText : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox.expand(
                    child: Image.network(
                      set.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const _SetPlaceholder(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const _SetPlaceholder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                set.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.accentText : AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tối đa ${set.capacity} người',
                style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetPlaceholder extends StatelessWidget {
  const _SetPlaceholder();

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
        child: Icon(Icons.photo_camera_outlined, size: 26, color: Color(0xB3FFFFFF)),
      ),
    );
  }
}

/// Bảng giá dạng thẻ: mỗi dòng một khung giờ x loại ngày, giờ vàng tô vàng đậm.
class _PricingTable extends StatelessWidget {
  final List<PricingRuleModel> rules;

  const _PricingTable({required this.rules});

  static const _slotOrder = {'normal': 0, 'golden': 1};
  static const _dayOrder = {'weekday': 0, 'weekend': 1, 'holiday': 2};

  @override
  Widget build(BuildContext context) {
    final sorted = [...rules]..sort((a, b) {
        final bySlot = (_slotOrder[a.slotType] ?? 9).compareTo(_slotOrder[b.slotType] ?? 9);
        if (bySlot != 0) return bySlot;
        return (_dayOrder[a.dayType] ?? 9).compareTo(_dayOrder[b.dayType] ?? 9);
      });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.outline),
            _PriceRow(rule: sorted[i]),
          ],
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final PricingRuleModel rule;

  const _PriceRow({required this.rule});

  @override
  Widget build(BuildContext context) {
    final isGolden = rule.slotType == 'golden';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGolden ? 'Giờ vàng · 18:00 – 22:00' : 'Giờ thường · 08:00 – 18:00',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isGolden ? AppColors.statusWarning : AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dayLabel(rule.dayType),
                  style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: Formatters.vnd(rule.pricePerHour),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTitle,
                  ),
                ),
                const TextSpan(text: ' / giờ'),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: AppColors.textBody),
          ),
        ],
      ),
    );
  }

  static String _dayLabel(String dayType) {
    switch (dayType) {
      case 'weekend':
        return 'Cuối tuần';
      case 'holiday':
        return 'Ngày lễ';
      default:
        return 'Ngày thường (T2 – T6)';
    }
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final initial = review.userName.trim().isEmpty
        ? '?'
        : review.userName.trim().split(' ').last[0].toUpperCase();
    final d = review.createdAt.toLocal();
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfacePink,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentText,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                    ),
                    Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                  ],
                ),
              ),
              Semantics(
                label: '${review.stars} trên 5 sao',
                excludeSemantics: true,
                child: Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: AppColors.ratingGold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!.trim(),
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
            ),
          ],
        ],
      ),
    );
  }
}