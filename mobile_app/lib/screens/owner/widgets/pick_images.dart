import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';

/// Hỏi chụp ảnh hay chọn từ thư viện (chọn được nhiều ảnh, tối đa [max]).
/// Trả về danh sách đường dẫn ảnh trên máy; rỗng nếu người dùng huỷ.
/// Ném [StateError] với câu tiếng Việt khi không mở được máy ảnh / thư viện.
Future<List<String>> pickStudioImages(BuildContext context, {int max = 10}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                'Thêm ảnh',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTitle,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Chọn từ thư viện (tối đa $max ảnh)'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh mới'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return const [];

  // Thu nhỏ + nén trên máy: ảnh 12MP gốc vừa chậm vừa dễ vượt giới hạn 8MB/ảnh của backend.
  const maxSide = 1600.0;
  const quality = 85;
  final picker = ImagePicker();
  try {
    if (source == ImageSource.camera || max <= 1) {
      final one = await picker.pickImage(
        source: source,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: quality,
      );
      return one == null ? const [] : [one.path];
    }
    final many = await picker.pickMultiImage(
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
      limit: max, // một số máy không hỗ trợ giới hạn -> cắt lại ở dưới
    );
    return many.take(max).map((x) => x.path).toList();
  } catch (_) {
    throw StateError(
      'Không mở được ${source == ImageSource.camera ? 'máy ảnh' : 'thư viện ảnh'}. '
      'Kiểm tra quyền truy cập của ứng dụng trong Cài đặt.',
    );
  }
}
