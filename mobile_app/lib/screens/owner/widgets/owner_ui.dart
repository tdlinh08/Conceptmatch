import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

// Mảnh giao diện dùng chung cho các màn quản lý của chủ studio.

void showToast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

/// Hộp thoại xác nhận; trả về true khi người dùng đồng ý.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive ? TextButton.styleFrom(foregroundColor: AppColors.statusError) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Tiêu đề mục: chữ đậm + (tuỳ chọn) chữ phụ bên phải hoặc nút.
class OwnerSectionHeader extends StatelessWidget {
  final String text;
  final String? trailing;
  final String? action;
  final VoidCallback? onAction;

  const OwnerSectionHeader(this.text, {super.key, this.trailing, this.action, this.onAction});

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
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

/// Nhãn nhỏ màu xám, vd "Đang ẩn", "Đã nghỉ".
class MutedTag extends StatelessWidget {
  final String text;
  const MutedTag(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textBody),
      ),
    );
  }
}

/// Khung thông báo nhỏ (gợi ý / cảnh báo).
class HintBox extends StatelessWidget {
  final String text;
  final bool warning;
  final IconData? icon;

  const HintBox(this.text, {super.key, this.warning = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.statusWarning : AppColors.textBody;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? AppColors.statusWarning.withValues(alpha: 0.1) : AppColors.surfacePink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? (warning ? Icons.info_outline_rounded : Icons.lightbulb_outline_rounded),
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, height: 1.5, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Màn đang tải lần đầu / lỗi tải (kèm nút thử lại).
class LoadState extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;

  const LoadState({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (error == null) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

/// Lớp phủ mờ + vòng xoay khi đang lưu.
class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Color(0x33000000),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// Nút lưu toàn chiều ngang, có vòng xoay khi đang lưu.
class SaveButton extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onPressed;

  const SaveButton({super.key, required this.label, required this.saving, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: saving ? null : onPressed,
      child: saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
            )
          : Text(label),
    );
  }
}

/// Ô nhập tiền: tự chèn dấu chấm hàng nghìn ("350.000"), đọc lại bằng [parseMoney].
class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final int min;

  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.min = 0,
  });

  static int? parseMoney(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : int.parse(digits);
  }

  static String format(num value) {
    final digits = value.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
      b.write(digits[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
        _ThousandsFormatter(),
      ],
      decoration: InputDecoration(labelText: label, suffixText: 'đ', helperText: helper),
      validator: (v) {
        final n = parseMoney(v ?? '');
        if (n == null) return min > 0 ? 'Nhập số tiền' : 'Nhập số tiền (0 nếu không thu)';
        if (n < min) return 'Tối thiểu ${format(min)}đ';
        return null;
      },
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final n = MoneyField.parseMoney(newValue.text);
    if (n == null) return newValue.copyWith(text: '');
    final text = MoneyField.format(n);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Ô nhập số nguyên trong khoảng [min]..[max].
class IntField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int min;
  final int max;
  final String? helper;
  final String? Function(int value)? extraValidator;

  const IntField({
    super.key,
    required this.controller,
    required this.label,
    required this.min,
    required this.max,
    this.helper,
    this.extraValidator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
      decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 2),
      validator: (v) {
        final n = int.tryParse((v ?? '').trim());
        if (n == null) return 'Nhập số';
        if (n < min || n > max) return 'Từ $min đến $max';
        return extraValidator?.call(n);
      },
    );
  }
}
