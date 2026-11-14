import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/visual_match.dart';
import '../../providers/studios_provider.dart';
import '../studios/all_studios_screen.dart';
import '../studios/set_detail_screen.dart';
import '../studios/studio_detail_screen.dart';

/// TÌM BỐI CẢNH BẰNG HÌNH ẢNH (AI Visual Search — lõi của đề tài).
/// Người dùng chụp / chọn 1 ảnh concept (moodboard, ảnh mẫu trên mạng...) -> backend gửi sang
/// AI Service (CLIP ViT-B/32 + FAISS) -> danh sách bối cảnh giống nhất kèm độ tương đồng.
class VisualSearchScreen extends StatefulWidget {
  const VisualSearchScreen({super.key});

  @override
  State<VisualSearchScreen> createState() => _VisualSearchScreenState();
}

class _VisualSearchScreenState extends State<VisualSearchScreen> {
  String? _imagePath;
  bool _loading = false;
  List<VisualMatch>? _results;
  int? _tookMs;
  String? _error;
  bool _aiDown = false; // 503: AI service không phản hồi -> gợi ý tìm bằng từ khoá

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280, // CLIP chỉ cần 224px; thu nhỏ để gửi nhanh
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (x == null || !mounted) return;
      setState(() => _imagePath = x.path);
      await _search();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không mở được ${source == ImageSource.camera ? 'máy ảnh' : 'thư viện ảnh'}. '
            'Kiểm tra quyền truy cập trong Cài đặt.',
          ),
        ),
      );
    }
  }

  Future<void> _search() async {
    final path = _imagePath;
    if (path == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _aiDown = false;
      _results = null;
    });
    try {
      final lower = path.toLowerCase();
      final sub = lower.endsWith('.png') ? 'png' : (lower.endsWith('.webp') ? 'webp' : 'jpeg');
      final res = await ApiClient().dio.post(
            '/ai/visual-search',
            data: FormData.fromMap({
              'image': await MultipartFile.fromFile(path, contentType: DioMediaType('image', sub)),
              'top_k': '12',
            }),
            options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
          );
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _results = (data['results'] as List)
            .map((e) => VisualMatch.fromJson(e as Map<String, dynamic>))
            .toList();
        _tookMs = (data['took_ms'] as num?)?.toInt();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiDown = e is DioException && e.response?.statusCode == 503;
        _error = apiErrorMessage(e, fallback: 'Không tìm được, vui lòng thử lại');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Mở chi tiết bối cảnh (cần dữ liệu studio đầy đủ để hiện gói thuê + đặt lịch).
  Future<void> _open(VisualMatch m) async {
    final detail = await context.read<StudiosProvider>().fetchStudioDetail(m.studioId);
    if (!mounted) return;
    final set = detail?.sets.where((s) => s.id == m.setId).firstOrNull;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => detail != null && set != null
            ? SetDetailScreen(studio: detail, set: set)
            : StudioDetailScreen(studioId: m.studioId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm bằng hình ảnh')),
      body: SafeArea(
        top: false,
        child: _imagePath == null ? _buildIntro() : _buildSearch(),
      ),
    );
  }

  // ---------------------------------------------------------------- màn mở đầu
  Widget _buildIntro() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.moonPink, AppColors.dustyMauve],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Center(
            child: Icon(Icons.image_search_rounded, size: 72, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Có ảnh concept ưng ý?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppColors.textTitle),
        ),
        const SizedBox(height: 8),
        const Text(
          'Chụp hoặc chọn một bức ảnh (moodboard, ảnh mẫu trên Pinterest...). '
          'AI sẽ tìm những bối cảnh studio có không gian giống nhất.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textBody),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Chọn ảnh từ thư viện'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Chụp ảnh'),
        ),
        const SizedBox(height: 28),
        const _Tip(icon: Icons.crop_free_rounded, text: 'Ảnh thấy rõ không gian: phông nền, ánh sáng, đồ trang trí.'),
        const _Tip(icon: Icons.person_off_outlined, text: 'Ảnh ít người / người nhỏ trong khung cho kết quả tốt hơn.'),
        const _Tip(icon: Icons.photo_size_select_large_rounded, text: 'JPG, PNG hoặc WEBP, tối đa 10MB.'),
      ],
    );
  }

  // ---------------------------------------------------------------- ảnh + kết quả
  Widget _buildSearch() {
    final results = _results;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(File(_imagePath!), width: 96, height: 96, fit: BoxFit.cover),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loading
                            ? 'Đang phân tích bối cảnh…'
                            : results == null
                                ? 'Chưa có kết quả'
                                : results.isEmpty
                                    ? 'Chưa tìm thấy bối cảnh phù hợp'
                                    : '${results.length} bối cảnh giống nhất',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textTitle),
                      ),
                      if (_tookMs != null && !_loading && results != null)
                        Text(
                          'AI xử lý trong ${(_tookMs! / 1000).toStringAsFixed(1).replaceAll('.', ',')} giây',
                          style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Ảnh khác'),
                          ),
                          TextButton.icon(
                            onPressed: _loading ? null : () => _pick(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: const Text('Chụp'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          SliverFillRemaining(hasScrollBody: false, child: _buildError())
        else if (results != null && results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text(
                    'Hệ thống chưa có bối cảnh nào để so khớp, hoặc ảnh quá khác biệt. '
                    'Thử ảnh khác hoặc tìm bằng từ khoá.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.5, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _openKeyword, child: const Text('Tìm bằng từ khoá')),
                ],
              ),
            ),
          )
        else if (results != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _MatchCard(match: results[i], rank: i + 1, onTap: () => _open(results[i])),
                childCount: results.length,
              ),
            ),
          ),
      ],
    );
  }

  void _openKeyword() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AllStudiosScreen()),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(_aiDown ? Icons.cloud_off_rounded : Icons.error_outline_rounded, size: 48, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(height: 1.5, color: AppColors.textBody)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(onPressed: _search, child: const Text('Thử lại')),
              if (_aiDown) OutlinedButton(onPressed: _openKeyword, child: const Text('Tìm bằng từ khoá')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.accentText),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textBody))),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final VisualMatch match;
  final int rank;
  final VoidCallback onTap;
  const _MatchCard({required this.match, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = match;
    final strong = m.similarity >= 0.85;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    m.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: AppColors.surfacePink),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: strong ? AppColors.primary : const Color(0xCC161018),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$rank · ${m.level} ${m.percent}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.setName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textTitle),
                  ),
                  Text(
                    '${m.studioName} · ${m.district}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.minPrice == null ? 'Chưa có giá' : 'Từ ${Formatters.vnd(m.minPrice!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentText),
                        ),
                      ),
                      if (m.reviewCount > 0) ...[
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.ratingGold),
                        Text(m.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                      ],
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
