import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/studio_detail_model.dart';
import '../bookings/booking_screen.dart';
import 'widgets/package_card.dart';
import 'widgets/photo_viewer.dart';

/// Chi tiết 1 bối cảnh (set): album ảnh, mô tả, sức chứa, các gói thuê
/// và nút đặt lịch với bối cảnh này được chọn sẵn.
class SetDetailScreen extends StatefulWidget {
  final StudioDetailModel studio;
  final StudioSetModel set;

  const SetDetailScreen({super.key, required this.studio, required this.set});

  @override
  State<SetDetailScreen> createState() => _SetDetailScreenState();
}

class _SetDetailScreenState extends State<SetDetailScreen> {
  int _imageIndex = 0;

  StudioSetModel get _set => widget.set;

  void _book({String? packageId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          studio: widget.studio,
          initialSetId: _set.id,
          initialPackageId: packageId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gallery = _set.gallery;
    final description = _set.description?.trim() ?? '';
    final tag = _set.styleTag?.trim() ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildGallery(gallery)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList.list(
              children: [
                if (tag.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePink,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          tag[0].toUpperCase() + tag.substring(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  _set.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.studio.name,
                  style: const TextStyle(fontSize: 14, color: AppColors.textBody),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Fact(icon: Icons.groups_outlined, text: 'Tối đa ${_set.capacity} người'),
                    _Fact(icon: Icons.photo_library_outlined, text: '${gallery.length} ảnh'),
                    if (_set.packages.isNotEmpty)
                      _Fact(icon: Icons.sell_outlined, text: '${_set.packages.length} gói thuê'),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _Title('Mô tả'),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textBody),
                  ),
                ],
                if (gallery.length > 1) ...[
                  const SizedBox(height: 24),
                  _Title('Ảnh bối cảnh', trailing: '${gallery.length} ảnh'),
                  const SizedBox(height: 10),
                  _buildGrid(gallery),
                ],
                const SizedBox(height: 24),
                const _Title('Gói thuê'),
                const SizedBox(height: 10),
                if (_set.packages.isEmpty)
                  const Text(
                    'Bối cảnh này chưa mở nhận đặt lịch.',
                    style: TextStyle(fontSize: 14, color: AppColors.textBody),
                  )
                else
                  for (final pkg in _set.packages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PackageCard(package: pkg, onTap: () => _book(packageId: pkg.id)),
                    ),
                const SizedBox(height: 4),
                OpeningInfo(detail: widget.studio),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // Ảnh lớn vuốt ngang; bấm vào để xem toàn màn hình.
  Widget _buildGallery(List<String> gallery) {
    final topInset = MediaQuery.paddingOf(context).top;
    return AspectRatio(
      aspectRatio: 4 / 3.4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (gallery.isEmpty)
            const _Placeholder()
          else
            PageView.builder(
              itemCount: gallery.length,
              onPageChanged: (i) => setState(() => _imageIndex = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => PhotoViewerScreen.open(context, gallery, index: i, title: _set.name),
                child: Image.network(
                  gallery[i],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const _Placeholder(),
                  errorBuilder: (context, error, stackTrace) => const _Placeholder(),
                ),
              ),
            ),
          // Dải tối mờ phía trên để nút quay lại luôn nhìn rõ
          const IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 120,
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
          Positioned(
            top: topInset + 8,
            left: 12,
            child: Material(
              color: const Color(0x66161018),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Quay lại',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          if (gallery.length > 1)
            Positioned(
              right: 14,
              bottom: 14,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x99161018),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_imageIndex + 1}/${gallery.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Lưới ảnh nhỏ 3 cột; bấm ảnh nào mở trình xem đúng ảnh đó.
  Widget _buildGrid(List<String> gallery) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: gallery.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => PhotoViewerScreen.open(context, gallery, index: i, title: _set.name),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            gallery[i],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const _Placeholder(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final canBook = _set.isBookable;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: FilledButton(
            onPressed: canBook ? () => _book() : null,
            child: Text(canBook ? 'Đặt bối cảnh này' : 'Chưa nhận đặt lịch'),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  final String? trailing;

  const _Title(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.textTitle,
            ),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(fontSize: 13, color: AppColors.textFaint)),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Fact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textFaint),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textBody)),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

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
        child: Icon(Icons.photo_camera_outlined, size: 32, color: Color(0xB3FFFFFF)),
      ),
    );
  }
}
