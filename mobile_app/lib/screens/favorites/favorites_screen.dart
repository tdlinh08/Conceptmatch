import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/favorites_provider.dart';
import '../studios/widgets/photo_studio_card.dart';
import '../studios/studio_detail_screen.dart';

/// Tab "Đã lưu": lưới 2 cột các studio người dùng đã bấm tim.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesProvider>().fetchFavorites();
    });
  }

  void _openStudio(String studioId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudioDetailScreen(studioId: studioId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FavoritesProvider>();
    final studios = provider.favoriteStudios;
    final bottomInset = MediaQuery.paddingOf(context).bottom; // chừa chỗ thanh điều hướng nổi

    return Scaffold(
      body: SafeArea(
        bottom: false,
        // RefreshIndicator bọc CẢ trạng thái trống/lỗi (bản cũ chỉ bọc danh sách,
        // nên khi đang trống hoặc lỗi thì không kéo để tải lại được).
        child: RefreshIndicator(
          onRefresh: provider.fetchFavorites,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Expanded(
                        child: Text(
                          'Đã lưu',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            color: AppColors.textTitle,
                          ),
                        ),
                      ),
                      if (studios.isNotEmpty)
                        Text(
                          '${studios.length} studio',
                          style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
                        ),
                    ],
                  ),
                ),
              ),
              if (provider.isLoading && studios.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.errorMessage != null && studios.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Không tải được',
                    text: provider.errorMessage!,
                  ),
                )
              else if (studios.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Chưa lưu studio nào',
                    text: 'Bấm biểu tượng trái tim trên ảnh studio để lưu lại và xem nhanh ở đây.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.78, // thẻ cao hơn rộng, đủ chỗ 3 dòng chữ
                    ),
                    itemCount: studios.length,
                    itemBuilder: (context, index) {
                      final studio = studios[index];
                      // LayoutBuilder: truyền đúng kích thước ô lưới cho thẻ
                      // (thẻ tự thu nhỏ chữ khi rộng dưới 200px).
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
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyState({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 24, 36, 140),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
        ],
      ),
    );
  }
}