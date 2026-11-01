import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/review_model.dart';
import '../../providers/studios_provider.dart';
import 'widgets/review_card.dart';

/// Màn "Tất cả đánh giá" của 1 studio — tải từng trang 10 đánh giá,
/// cuộn gần cuối thì tải tiếp (GET /studios/:id/reviews?page=&limit=).
class ReviewsScreen extends StatefulWidget {
  final String studioId;
  final String studioName;
  final double avgRating;
  final int reviewCount;

  const ReviewsScreen({
    super.key,
    required this.studioId,
    required this.studioName,
    required this.avgRating,
    required this.reviewCount,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  static const _pageSize = 10;

  final _scroll = ScrollController();
  final List<ReviewModel> _items = [];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  String? _error;

  bool get _hasMore => _page == 0 || _items.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context
          .read<StudiosProvider>()
          .fetchReviewsPage(widget.studioId, page: _page + 1, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _page++;
        _total = res.total;
        _items.addAll(res.items);
        // Trang trả về rỗng -> coi như hết, tránh gọi lại mãi
        if (res.items.isEmpty) _total = _items.length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được đánh giá. Kiểm tra kết nối và thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đánh giá')),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Summary(
            name: widget.studioName,
            avg: widget.avgRating,
            count: _page == 0 ? widget.reviewCount : _total,
          ),
          const SizedBox(height: 20),
          ..._items.map((r) => ReviewCard(review: r)),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textBody),
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _loadMore, child: const Text('Thử lại')),
              ],
            )
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                'Chưa có đánh giá nào.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textBody),
              ),
            )
          else if (!_hasMore && _items.length > _pageSize)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Đã hiện hết đánh giá',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String name;
  final double avg;
  final int count;

  const _Summary({required this.name, required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfacePink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 18,
                      color: AppColors.ratingGold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count đánh giá · $name',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
