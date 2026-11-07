import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/constants/districts.dart';
import '../../core/utils/location_service.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/studios_provider.dart';
import 'studio_detail_screen.dart';
import 'widgets/photo_studio_card.dart';

/// Màn "Tất cả studio" — dùng chung cho "Xem tất cả" và bấm 1 concept ở Home
/// (vd Vintage -> mở sẵn bộ lọc Vintage). Tìm theo tên, lọc concept, quận, giá, đánh giá.
class AllStudiosScreen extends StatefulWidget {
  final String? initialStyleTag;
  final String? initialKeyword;
  final bool openFilterOnStart; // nút bộ lọc ở Home -> mở luôn bảng lọc

  const AllStudiosScreen({
    super.key,
    this.initialStyleTag,
    this.initialKeyword,
    this.openFilterOnStart = false,
  });

  @override
  State<AllStudiosScreen> createState() => _AllStudiosScreenState();
}

/// Mức giá tối đa của gói (VNĐ).
const _priceCaps = [300000, 500000, 1000000];

class _AllStudiosScreenState extends State<AllStudiosScreen> {
  late final TextEditingController _searchController;
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _started = false; // đã áp dụng bộ lọc ban đầu chưa

  StudiosProvider get _provider => context.read<StudiosProvider>();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialKeyword ?? '');
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _started = true);
      _provider.applyFilter(StudioFilter(
        keyword: widget.initialKeyword?.trim() ?? '',
        styleTag: widget.initialStyleTag,
      ));
      if (_provider.styleTags.isEmpty) _provider.fetchStyleTags();
      if (widget.openFilterOnStart) _openFilterSheet();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _provider.loadMore();
    }
  }

  void _apply(StudioFilter filter) {
    _provider.applyFilter(filter);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// Tự tìm sau khi người dùng ngừng gõ 400ms (không cần bấm Enter).
  void _onSearchChanged(String text) {
    setState(() {}); // cập nhật nút xoá chữ
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final keyword = text.trim();
      if (keyword != _provider.filter.keyword) {
        _apply(_provider.filter.copyWith(keyword: keyword));
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _clearAll() {
    _searchController.clear();
    setState(() {});
    _apply(const StudioFilter());
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<StudioFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _FilterSheet(initial: _provider.filter),
    );
    if (result != null) _apply(result);
  }

  void _openStudio(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudioDetailScreen(studioId: id)),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudiosProvider>();
    final filter = provider.filter;
    // Tiêu đề theo concept ĐANG CHỌN (chọn từ Home hay từ hàng chip trong màn đều được).
    // Khung hình đầu tiên bộ lọc chưa kịp áp dụng -> tạm dùng concept truyền vào.
    final tag = _started ? filter.styleTag : widget.initialStyleTag;
    final title = tag == null ? 'Tất cả studio' : 'Concept ${_capitalize(tag)}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Tên studio, quận, concept…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xoá',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _clearSearch,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(count: filter.sheetCount, onTap: _openFilterSheet),
              ],
            ),
          ),
          _buildStyleChips(provider.styleTags, filter),
          _buildResultBar(provider, filter),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildStyleChips(List<String> tags, StudioFilter filter) {
    if (tags.isEmpty) return const SizedBox(height: 4);
    final items = <String?>[null, ...tags];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tag = items[i];
          return Center(
            child: _Pill(
              label: tag == null ? 'Tất cả' : _capitalize(tag),
              selected: filter.styleTag == tag,
              onTap: () {
                if (filter.styleTag != tag) _apply(filter.copyWith(styleTag: () => tag));
              },
            ),
          );
        },
      ),
    );
  }

  /// "12 studio" + các bộ lọc đang bật (bấm x để bỏ từng cái).
  Widget _buildResultBar(StudiosProvider provider, StudioFilter filter) {
    final chips = <Widget>[
      if (filter.district != null)
        _ActiveChip(
          label: filter.district!,
          onRemove: () => _apply(filter.copyWith(district: () => null)),
        ),
      if (filter.maxPrice != null)
        _ActiveChip(
          label: 'Gói dưới ${Formatters.vnd(filter.maxPrice!)}',
          onRemove: () => _apply(filter.copyWith(maxPrice: () => null)),
        ),
      if (filter.minRating != null)
        _ActiveChip(
          label: 'Từ ${_ratingLabel(filter.minRating!)}★',
          onRemove: () => _apply(filter.copyWith(minRating: () => null)),
        ),
      for (final role in filter.services)
        _ActiveChip(
          label: _serviceLabel(role),
          onRemove: () => _apply(filter.copyWith(services: {...filter.services}..remove(role))),
        ),
      if (filter.sort == 'newest')
        _ActiveChip(
          label: 'Mới nhất',
          onRemove: () => _apply(filter.copyWith(sort: 'rating')),
        ),
      if (filter.sort == 'distance')
        _ActiveChip(
          label: 'Gần tôi',
          onRemove: () => _apply(filter.copyWith(sort: 'rating', location: () => null)),
        ),
    ];
    final countText = provider.isLoading && provider.studios.isEmpty
        ? 'Đang tìm…'
        : '${provider.totalCount} studio';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        children: [
          Text(countText, style: const TextStyle(fontSize: 13, color: AppColors.textFaint)),
          if (chips.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in chips) Padding(padding: const EdgeInsets.only(right: 6), child: c),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(StudiosProvider provider) {
    final studios = provider.studios;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (provider.isLoading && studios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null && studios.isEmpty) {
      return _EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Không tải được',
        text: provider.errorMessage!,
        actionLabel: 'Thử lại',
        onAction: () => _apply(provider.filter),
      );
    }
    if (studios.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Không tìm thấy studio phù hợp',
        text: 'Thử từ khoá khác, chọn concept khác hoặc nới bộ lọc nhé.',
        actionLabel: provider.filter.isEmpty ? null : 'Xoá bộ lọc',
        onAction: provider.filter.isEmpty ? null : _clearAll,
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.applyFilter(provider.filter),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78, // giống tab Đã lưu
              ),
              itemCount: studios.length,
              itemBuilder: (context, index) {
                final studio = studios[index];
                return LayoutBuilder(
                  builder: (context, constraints) => PhotoStudioCard(
                    studio: studio,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    onTap: () => _openStudio(studio.id),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
              child: provider.hasMore
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    )
                  : Text(
                      'Đã hiện tất cả ${provider.totalCount} studio',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

String _ratingLabel(double r) => r.toStringAsFixed(r % 1 == 0 ? 0 : 1).replaceAll('.', ',');

String _serviceLabel(String role) => role == 'makeup' ? 'Có trang điểm' : 'Có thợ ảnh';

// =============================================================================
// Bảng bộ lọc
// =============================================================================

class _FilterSheet extends StatefulWidget {
  final StudioFilter initial;

  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _sort = widget.initial.sort;
  late (double, double)? _location =
      widget.initial.lat != null && widget.initial.lng != null
          ? (widget.initial.lat!, widget.initial.lng!)
          : null;
  bool _locating = false;

  /// Chọn "Gần tôi": lấy vị trí điện thoại (xin quyền nếu cần) rồi mới bật.
  Future<void> _pickNearMe() async {
    setState(() => _locating = true);
    try {
      final me = await LocationService.current();
      if (!mounted) return;
      setState(() {
        _location = (me.latitude, me.longitude);
        _sort = 'distance';
      });
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }
  late String? _district = widget.initial.district;
  late int? _maxPrice = widget.initial.maxPrice;
  late double? _minRating = widget.initial.minRating;
  late final Set<String> _services = {...widget.initial.services};

  void _reset() => setState(() {
        _sort = 'rating';
        _location = null;
        _district = null;
        _maxPrice = null;
        _minRating = null;
        _services.clear();
      });

  void _toggleService(String role) => setState(() {
        if (!_services.remove(role)) _services.add(role);
      });

  void _done() {
    Navigator.of(context).pop(widget.initial.copyWith(
      sort: _sort,
      // Bỏ "Gần tôi" thì thôi gửi vị trí (không hiện khoảng cách nữa)
      location: () => _sort == 'distance' ? _location : null,
      district: () => _district,
      maxPrice: () => _maxPrice,
      minRating: () => _minRating,
      services: {..._services},
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bộ lọc',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _reset, child: const Text('Đặt lại')),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SheetLabel('SẮP XẾP'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          label: 'Đánh giá cao',
                          selected: _sort == 'rating',
                          onTap: () => setState(() => _sort = 'rating'),
                        ),
                        _Pill(
                          label: 'Mới nhất',
                          selected: _sort == 'newest',
                          onTap: () => setState(() => _sort = 'newest'),
                        ),
                        _Pill(
                          label: _locating ? 'Đang lấy vị trí…' : 'Gần tôi',
                          selected: _sort == 'distance',
                          onTap: _locating ? () {} : _pickNearMe,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SheetLabel('KHU VỰC', hint: 'Quận nơi studio đặt địa chỉ'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          label: 'Mọi quận',
                          selected: _district == null,
                          onTap: () => setState(() => _district = null),
                        ),
                        for (final d in kDistricts)
                          _Pill(
                            label: d,
                            selected: _district == d,
                            onTap: () => setState(() => _district = d),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SheetLabel(
                      'GIÁ GÓI THUÊ',
                      hint: 'Studio có ít nhất 1 gói thuê dưới mức này (chưa gồm phụ thu, dịch vụ thêm)',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          label: 'Mọi mức giá',
                          selected: _maxPrice == null,
                          onTap: () => setState(() => _maxPrice = null),
                        ),
                        for (final p in _priceCaps)
                          _Pill(
                            label: 'Dưới ${Formatters.vnd(p)}',
                            selected: _maxPrice == p,
                            onTap: () => setState(() => _maxPrice = p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SheetLabel('ĐÁNH GIÁ', hint: 'Điểm trung bình từ khách đã chụp'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          label: 'Tất cả',
                          selected: _minRating == null,
                          onTap: () => setState(() => _minRating = null),
                        ),
                        for (final r in const [4.0, 4.5])
                          _Pill(
                            label: 'Từ ${_ratingLabel(r)}★',
                            selected: _minRating == r,
                            onTap: () => setState(() => _minRating = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SheetLabel(
                      'DỊCH VỤ KÈM THEO',
                      hint: 'Studio có thợ để bạn đặt thêm khi chọn lịch (chọn được cả hai)',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final role in const ['photographer', 'makeup'])
                          _Pill(
                            label: _serviceLabel(role),
                            selected: _services.contains(role),
                            onTap: () => _toggleService(role),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(onPressed: _done, child: const Text('Xem kết quả')),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Widget con
// =============================================================================

class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FilterButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Semantics(
      button: true,
      label: active ? 'Bộ lọc, đang bật $count' : 'Bộ lọc',
      excludeSemantics: true,
      child: Material(
        color: active ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: active ? BorderSide.none : const BorderSide(color: AppColors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: active ? AppColors.onPrimary : AppColors.textTitle,
                ),
                if (active)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.moonPink,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : const BorderSide(color: AppColors.outlineStrong),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.onPrimary : AppColors.textBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bộ lọc đang bật, bấm x để bỏ.
class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfacePink,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentText,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close_rounded, size: 14, color: AppColors.accentText),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;
  final String? hint; // giải thích ngắn: lọc theo tiêu chí gì

  const _SheetLabel(this.text, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textFaint,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(hint!, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textBody)),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // Cuộn được: khi bàn phím mở, chiều cao còn lại nhỏ -> không bị tràn (lỗi "BOTTOM OVERFLOWED")
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(36, 32, 36, 80),
      children: [
        Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.surfacePink, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.accentText),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ],
    );
  }
}
