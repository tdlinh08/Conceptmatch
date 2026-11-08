import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';

/// Gửi báo cáo vi phạm về 1 studio hoặc 1 đánh giá (POST /reports).
/// [targetType]: 'studio' | 'review'. Hiện bảng chọn lý do; gửi xong báo kết quả bằng SnackBar.
Future<void> showReportSheet(BuildContext context, {required String targetType, required String targetId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId),
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final String targetId;
  const _ReportSheet({required this.targetType, required this.targetId});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _studioReasons = [
    'Thông tin sai sự thật',
    'Ảnh không đúng thực tế',
    'Yêu cầu chuyển tiền ngoài ứng dụng',
    'Thái độ phục vụ không tốt',
    'Studio đã ngừng hoạt động',
    'Khác',
  ];
  static const _reviewReasons = [
    'Ngôn từ xúc phạm',
    'Nội dung sai sự thật',
    'Spam / quảng cáo',
    'Không liên quan đến studio',
    'Khác',
  ];

  String? _reason;
  final _detail = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ApiClient().dio.post('/reports', data: {
        'target_type': widget.targetType,
        'target_id': widget.targetId,
        'reason': _reason,
        if (_detail.text.trim().isNotEmpty) 'detail': _detail.text.trim(),
      });
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã gửi báo cáo. Quản trị viên sẽ xem xét và báo lại cho bạn.')),
      );
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, fallback: 'Không gửi được báo cáo'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.targetType == 'studio' ? _studioReasons : _reviewReasons;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.targetType == 'studio' ? 'Báo cáo studio' : 'Báo cáo đánh giá',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textTitle),
              ),
              const SizedBox(height: 4),
              const Text(
                'Quản trị viên sẽ xem xét. Thông tin của bạn không hiển thị với bên bị báo cáo.',
                style: TextStyle(fontSize: 13, color: AppColors.textFaint),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  children: [
                    for (final r in reasons)
                      RadioListTile<String>(contentPadding: EdgeInsets.zero, dense: true, value: r, title: Text(r)),
                  ],
                ),
              ),
              TextField(
                controller: _detail,
                maxLines: 3,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Mô tả thêm (không bắt buộc)'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _reason == null || _sending ? null : _send,
                child: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Gửi báo cáo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
