import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/studios_provider.dart';
import '../studios/all_studios_screen.dart';
import '../studios/studio_detail_screen.dart';
import '../studios/widgets/featured_studio_card.dart';
import '../studios/widgets/category_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StudiosProvider>();
      provider.fetchFeatured();
      provider.fetchStyleTags();
      provider.fetchForYou();
    });
  }

  

  void _goToAllStudios({String? styleTag, String? keyword}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllStudiosScreen(
          initialStyleTag: styleTag,
          initialKeyword: keyword,
        ),
      ),
    );
  }

  void _goToStudioDetail(String studioId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudioDetailScreen(studioId: studioId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studiosProvider = context.watch<StudiosProvider>();
    final userName = context.watch<AuthProvider>().currentUser?.fullName ?? '';
    final firstName = userName.isNotEmpty ? userName.split(' ').last : '';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final provider = context.read<StudiosProvider>();
            await Future.wait([
              provider.fetchFeatured(),
              provider.fetchStyleTags(),
              provider.fetchForYou(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildHeader(firstName),
              _buildSearchEntry(),
              _buildAiSearchBanner(),
              sectionTitle(
                'Nổi bật',
                trailing: GestureDetector(
                  onTap: () => _goToAllStudios(),
                  child: const Text(
                    'Xem tất cả',
                    style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              _buildFeaturedCarousel(studiosProvider),
              _buildCategorySection(studiosProvider),
              sectionTitle('Dành cho bạn'),
              _buildForYouCarousel(studiosProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String firstName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            firstName.isNotEmpty ? 'Xin chào, $firstName 👋' : 'Xin chào 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Icon(Icons.notifications_none, color: AppColors.textPrimary, size: 24),
        ],
      ),
    );
  }

  Widget _buildSearchEntry() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _goToAllStudios(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated, // ĐỔI: trước là AppColors.surfaceVariant
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1), // THÊM MỚI
          ),
          child: Row( // bỏ "const" ở đây vì bên trong giờ dùng màu không phải hằng số
            children: [
              Icon(Icons.search, color: AppColors.textMuted), // ĐỔI: trước là AppColors.textPrimary
              const SizedBox(width: 10),
              Text('Tìm theo tên studio...', style: TextStyle(color: AppColors.textMuted)), // ĐỔI: trước là AppColors.textSecondary
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildAiSearchBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            // TODO: điều hướng sang màn AI Visual Search — sẽ làm ở Giai đoạn tiếp theo.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng AI Search đang được xây dựng ✨')),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              // Gradient 3 điểm dừng: Sky Blue -> Ice Blue -> thoáng qua Amber
              // Gold ở cuối, tạo chiều sâu mà vẫn giữ đúng quy tắc "10%" (chỉ
              // 1 dải rất mỏng ở cuối, không lấn át tông xanh chủ đạo).
              gradient: LinearGradient(
                colors: [
                  AppColors.accentGradientStart,
                  AppColors.accentGradientEnd,
                  AppColors.accentPeach.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.7, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGradientStart.withValues(alpha: 0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.textPrimary, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tìm studio bằng hình ảnh',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Upload ảnh moodboard, AI gợi ý studio phù hợp nhất',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: AppColors.textPrimary, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String text, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}

  Widget _buildFeaturedCarousel(StudiosProvider provider) {
    if (provider.isLoadingFeatured && provider.featuredStudios.isEmpty) {
      return const SizedBox(height: 170, child: Center(child: CircularProgressIndicator()));
    }
    if (provider.featuredStudios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('Chưa có studio nổi bật', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: provider.featuredStudios.length,
        itemBuilder: (context, index) {
          final studio = provider.featuredStudios[index];
          return FeaturedStudioCard(
            studio: studio,
            onTap: () => _goToStudioDetail(studio.id),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(StudiosProvider provider) {
    if (provider.styleTags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Khám phá theo phong cách'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: provider.styleTags
                  .map((tag) => CategoryChip(
                        label: tag,
                        onTap: () => _goToAllStudios(styleTag: tag),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForYouCarousel(StudiosProvider provider) {
    if (provider.isLoadingForYou && provider.forYouStudios.isEmpty) {
      return const SizedBox(height: 170, child: Center(child: CircularProgressIndicator()));
    }
    if (provider.forYouStudios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Xem thêm studio để nhận gợi ý phù hợp với bạn',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: provider.forYouStudios.length,
        itemBuilder: (context, index) {
          final studio = provider.forYouStudios[index];
          return FeaturedStudioCard(
            studio: studio,
            onTap: () => _goToStudioDetail(studio.id),
          );
        },
      ),
    );
  }
}
