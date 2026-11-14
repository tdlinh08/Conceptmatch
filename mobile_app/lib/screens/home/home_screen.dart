import 'package:flutter/material.dart';
import '../ai/visual_search_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/studio_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../notifications/notifications_screen.dart';
import '../../providers/studios_provider.dart';
import '../studios/all_studios_screen.dart';
import '../studios/studio_detail_screen.dart';
import '../studios/widgets/photo_studio_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedTag; // concept đang xem nhanh trên Home (null = "Tất cả")

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHomeData());
  }

  Future<void> _loadHomeData() {
    final provider = context.read<StudiosProvider>();
    return Future.wait([
      provider.fetchFeatured(),
      provider.fetchStyleTags(),
      provider.fetchForYou(),
      context.read<NotificationsProvider>().fetchUnreadCount(),
      // Kéo để làm mới: tải lại cả concept đang xem
      if (_selectedTag != null) provider.fetchConceptPreview(_selectedTag!, force: true),
    ]);
  }

  /// Bấm chip concept: xem nhanh ngay trên Home; bấm lại chip đang chọn hoặc "Tất cả" để ẩn.
  void _onSelectTag(String? tag) {
    setState(() => _selectedTag = tag == _selectedTag ? null : tag);
    if (_selectedTag != null) {
      context.read<StudiosProvider>().fetchConceptPreview(_selectedTag!);
    }
  }

  // ---------------------------------------------------------------------------
  // Điều hướng
  // ---------------------------------------------------------------------------

  void _goToAllStudios({String? styleTag, String? keyword, bool openFilter = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllStudiosScreen(
          initialStyleTag: styleTag,
          initialKeyword: keyword,
          openFilterOnStart: openFilter,
        ),
      ),
    );
  }

  void _goToStudioDetail(String studioId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudioDetailScreen(studioId: studioId)),
    );
  }

  void _openAiSearch() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VisualSearchScreen()));
  }

  Future<void> _openNotifications() async {
    final notifications = context.read<NotificationsProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    notifications.fetchUnreadCount(); // quay lại Home: cập nhật chấm đỏ
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final studiosProvider = context.watch<StudiosProvider>();
    final fullName = context.watch<AuthProvider>().currentUser?.fullName ?? '';
    final firstName = fullName.trim().isEmpty ? '' : fullName.trim().split(' ').last;

    // Thanh điều hướng nổi (main_shell.dart, extendBody: true) che lên đáy màn:
    // cộng chiều cao của nó vào padding đáy để thẻ cuối không bị che khi cuộn hết.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadHomeData,
          child: ListView(
            padding: EdgeInsets.only(bottom: bottomInset + 24),
            children: [
              _buildHeader(firstName),
              _buildSearchRow(),
              _buildAiCard(),
              _buildStyleChips(studiosProvider.styleTags),
              if (_selectedTag != null) ..._buildConceptPreview(studiosProvider, _selectedTag!),
              _sectionHeader('Nổi bật', onSeeAll: () => _goToAllStudios()),
              _buildStudioCarousel(
                studios: studiosProvider.featuredStudios,
                isLoading: studiosProvider.isLoadingFeatured,
                emptyText: 'Chưa có studio nổi bật',
                cardWidth: 240,
                cardHeight: 220,
              ),
              _sectionHeader('Dành cho bạn'),
              _buildStudioCarousel(
                studios: studiosProvider.forYouStudios,
                isLoading: studiosProvider.isLoadingForYou,
                emptyText: 'Xem thêm vài studio để nhận gợi ý hợp gu bạn',
                cardWidth: 170,
                cardHeight: 200,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 1. Lời chào + tiêu đề lớn + nút thông báo ----
  Widget _buildHeader(String firstName) {
    final greeting = firstName.isEmpty ? _greeting() : '${_greeting()}, $firstName';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: 'Tìm bối cảnh cho\n'),
                      TextSpan(
                        text: 'buổi chụp',
                        style: TextStyle(color: AppColors.accentText),
                      ),
                      TextSpan(text: ' tiếp theo'),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: AppColors.textTitle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CircleIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Thông báo',
            badge: context.watch<NotificationsProvider>().unread,
            onPressed: _openNotifications,
          ),
        ],
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 13) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  // ---- 2. Ô tìm kiếm (bấm để mở màn Tất cả studio) + nút lọc ----
  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Tìm kiếm studio',
              excludeSemantics: true,
              child: Material(
                color: AppColors.surface,
                shape: const StadiumBorder(side: BorderSide(color: AppColors.outline)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => _goToAllStudios(),
                  child: const SizedBox(
                    height: 52,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 22, color: AppColors.textFaint),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tên studio, quận, concept…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, color: AppColors.textFaint),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Bộ lọc',
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _goToAllStudios(openFilter: true), // mở luôn bảng lọc
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.tune_rounded, size: 22, color: AppColors.onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 3. Thẻ "Tìm bằng hình ảnh" ----
  Widget _buildAiCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
        decoration: BoxDecoration(
          color: AppColors.surfacePink,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.dustyMauve.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TÌM BẰNG HÌNH ẢNH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: AppColors.accentText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Có ảnh mẫu? Để AI chọn studio giống nhất.',
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _openAiSearch,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text('Tải ảnh moodboard'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // Phải ghi rõ font: textStyle ở đây THAY HẲN (không gộp) textStyle của theme.
                      textStyle: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const _MoodboardStack(),
          ],
        ),
      ),
    );
  }

  // ---- 4. Chip concept: bấm để xem nhanh vài studio ngay bên dưới ----
  Widget _buildStyleChips(List<String> styleTags) {
    if (styleTags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: styleTags.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _StyleChip(
                label: 'Tất cả',
                selected: _selectedTag == null,
                onTap: () => _onSelectTag(null),
              );
            }
            final tag = styleTags[index - 1];
            return _StyleChip(
              label: _capitalize(tag),
              selected: _selectedTag == tag,
              onTap: () => _onSelectTag(tag),
            );
          },
        ),
      ),
    );
  }

  /// Mục "Concept Retro": tối đa 6 studio cuộn ngang + "Xem thêm" mở danh sách đầy đủ.
  List<Widget> _buildConceptPreview(StudiosProvider provider, String tag) {
    final studios = provider.conceptPreviews[tag] ?? const <StudioModel>[];
    final total = provider.conceptTotals[tag] ?? 0;
    final loading = provider.isLoadingConcept(tag) && studios.isEmpty;
    final hasMore = total > studios.length;
    void openAll() => _goToAllStudios(styleTag: tag);

    const cardWidth = 200.0;
    const cardHeight = 220.0;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Concept '),
                    TextSpan(
                      text: _capitalize(tag),
                      style: const TextStyle(color: AppColors.accentText),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.textTitle,
                ),
              ),
            ),
            TextButton(
              onPressed: openAll,
              child: Text(total > 0 ? 'Xem thêm ($total)' : 'Xem thêm'),
            ),
          ],
        ),
      ),
      if (loading)
        const _SkeletonRow(cardWidth: cardWidth, cardHeight: cardHeight)
      else if (studios.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Chưa có studio nào thuộc concept này.',
            style: TextStyle(color: AppColors.textBody, fontSize: 14),
          ),
        )
      else
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: studios.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              if (index == studios.length) {
                return _SeeMoreCard(
                  label: 'Xem thêm\n${total - studios.length} studio',
                  width: 120,
                  height: cardHeight,
                  onTap: openAll,
                );
              }
              final studio = studios[index];
              return PhotoStudioCard(
                studio: studio,
                width: cardWidth,
                height: cardHeight,
                onTap: () => _goToStudioDetail(studio.id),
              );
            },
          ),
        ),
    ];
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  // ---- 5. Tiêu đề mục ----
  Widget _sectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 28, onSeeAll == null ? 20 : 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.textTitle,
              ),
            ),
          ),
          if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('Xem tất cả')),
        ],
      ),
    );
  }

  // ---- 6. Dải thẻ studio cuộn ngang ----
  Widget _buildStudioCarousel({
    required List<StudioModel> studios,
    required bool isLoading,
    required String emptyText,
    required double cardWidth,
    required double cardHeight,
  }) {
    if (isLoading && studios.isEmpty) {
      return _SkeletonRow(cardWidth: cardWidth, cardHeight: cardHeight);
    }
    if (studios.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(emptyText, style: const TextStyle(color: AppColors.textBody, fontSize: 14)),
      );
    }
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: studios.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final studio = studios[index];
          return PhotoStudioCard(
            studio: studio,
            width: cardWidth,
            height: cardHeight,
            onTap: () => _goToStudioDetail(studio.id),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Widget nhỏ dùng riêng cho Home
// =============================================================================

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badge; // số chưa đọc; 0 = không hiện

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge > 0 ? '$tooltip, $badge chưa đọc' : tooltip, // đọc được bằng trình đọc màn hình
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.outline)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: AppColors.textTitle),
                if (badge > 0)
                  Positioned(
                    top: 4,
                    right: 2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.statusError,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

class _StyleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StyleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: selected ? BorderSide.none : const BorderSide(color: AppColors.outlineStrong),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
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

/// Thẻ cuối dải concept: mở danh sách đầy đủ của concept đó.
class _SeeMoreCard extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _SeeMoreCard({
    required this.label,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: AppColors.surfacePink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.dustyMauve.withValues(alpha: 0.28)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, color: AppColors.accentText),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3 ô ảnh xếp chồng, xoay nhẹ — hình minh hoạ cho thẻ AI (chỉ để trang trí).
class _MoodboardStack extends StatelessWidget {
  const _MoodboardStack();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 96,
        height: 108,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 18,
              child: _MoodTile(angle: -0.16, colors: [Color(0xFFD7B3A6), Color(0xFF7E6270)]),
            ),
            Positioned(
              left: 36,
              top: 28,
              child: _MoodTile(angle: 0.14, colors: [Color(0xFFEBCBD6), Color(0xFFB58FA9)]),
            ),
            Positioned(
              left: 18,
              top: 0,
              child: _MoodTile(angle: 0, colors: [Color(0xFFDCD0DC), Color(0xFF8B7690)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  final double angle;
  final List<Color> colors;

  const _MoodTile({required this.angle, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 58,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surface, width: 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

/// Khung xám chờ dữ liệu (thay cho vòng xoay), giữ đúng kích thước thẻ thật.
class _SkeletonRow extends StatelessWidget {
  final double cardWidth;
  final double cardHeight;

  const _SkeletonRow({required this.cardWidth, required this.cardHeight});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}