import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
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
  StudioDetailModel? _detail;
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
    context.read<StudiosProvider>().recordView(widget.studioId);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasError || _detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.textSecondary, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Không tải được thông tin studio',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            ),
          ),
        ),
      );
    }

    final detail = _detail!;
    final favoritesProvider = context.watch<FavoritesProvider>();
    final isFavorited = favoritesProvider.isFavorited(detail.id);

    final studioSummary = StudioModel(
      id: detail.id,
      name: detail.name,
      district: detail.district,
      avgRating: detail.avgRating,
      coverImage: detail.images.isEmpty
          ? null
          : detail.images.firstWhere((i) => i.isCover, orElse: () => detail.images.first).url,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.background,
            actions: [
              IconButton(
                icon: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: isFavorited ? AppColors.accent : Colors.white,
                ),
                onPressed: () =>
                    context.read<FavoritesProvider>().toggleFavorite(studioSummary),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _buildGallery(detail)),
          ),
          SliverToBoxAdapter(child: _buildInfo(detail)),
          SliverToBoxAdapter(child: _buildSetsSection(detail)),
          SliverToBoxAdapter(child: _buildPricingSection(detail)),
          SliverToBoxAdapter(child: _buildReviewsSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _buildBookingBar(),
    );
  }

  Widget _buildGallery(StudioDetailModel detail) {
    if (detail.images.isEmpty) {
      return Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(Icons.photo_camera, size: 48, color: AppColors.textSecondary),
        ),
      );
    }

    return PageView.builder(
      itemCount: detail.images.length,
      itemBuilder: (context, index) {
        final image = detail.images[index];
        return Image.network(
          image.url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.surfaceVariant,
            child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
          ),
        );
      },
    );
  }

  Widget _buildInfo(StudioDetailModel detail) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Amber Gold — đồng bộ với sao đánh giá ở mọi nơi khác trong app.
              const Icon(Icons.star, size: 18, color: AppColors.accentPeach),
              const SizedBox(width: 4),
              Text(
                '${detail.avgRating.toStringAsFixed(1)} (${detail.reviewCount} đánh giá)',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${detail.address}, ${detail.district}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          if (detail.description != null && detail.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              detail.description!,
              style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetsSection(StudioDetailModel detail) {
    if (detail.sets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(
            'Bối cảnh (Set)',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: detail.sets.length,
            itemBuilder: (context, index) {
              final set = detail.sets[index];
              return Container(
                width: 130,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBase,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.25)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(
                      set.avatarUrl,
                      height: 80,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 80,
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.photo_camera, color: AppColors.textSecondary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            set.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (set.styleTag != null)
                            Text(
                              set.styleTag!,
                              style: const TextStyle(color: AppColors.accent, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPricingSection(StudioDetailModel detail) {
    if (detail.pricingRules.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bảng giá',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          ...detail.pricingRules.map(
            (rule) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_slotTypeLabel(rule.slotType)} · ${_dayTypeLabel(rule.dayType)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    '${_formatPrice(rule.pricePerHour)}đ/giờ',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đánh giá gần đây',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          if (_reviews.isEmpty)
            const Text('Chưa có đánh giá nào', style: TextStyle(color: AppColors.textSecondary))
          else
            ..._reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.surfaceVariant,
                          child: Text(
                            review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          review.userName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(
                            5,
                            // Amber Gold — đồng bộ với mọi nơi khác.
                            (i) => Icon(
                              i < review.stars ? Icons.star : Icons.star_border,
                              size: 14,
                              color: AppColors.accentPeach,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (review.comment != null && review.comment!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        review.comment!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.cardBase,
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: () {
            // TODO: điều hướng sang màn Đặt lịch — sẽ làm ở Giai đoạn tiếp theo.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng đặt lịch đang được xây dựng 📅')),
            );
          },
          child: const Text('Đặt lịch ngay'),
        ),
      ),
    );
  }

  String _slotTypeLabel(String slotType) => slotType == 'golden' ? 'Giờ vàng' : 'Giờ thường';

  String _dayTypeLabel(String dayType) {
    switch (dayType) {
      case 'weekend':
        return 'Cuối tuần';
      case 'holiday':
        return 'Ngày lễ';
      default:
        return 'Ngày thường';
    }
  }

  String _formatPrice(double price) {
    final str = price.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
