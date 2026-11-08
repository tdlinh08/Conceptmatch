import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// Mảnh giao diện dùng chung cho trang quản trị (chạy cả web lẫn điện thoại).

/// Khung trang: tiêu đề lớn + nội dung, giới hạn chiều rộng để màn hình máy tính dễ đọc.
class AdminPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;

  const AdminPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
    this.onRefresh,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              color: AppColors.textTitle,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
                            ),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
    return SafeArea(
      child: onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list),
    );
  }
}

/// Ô số liệu ở trang tổng quan.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final bool highlight;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? AppColors.surfacePink : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: highlight ? AppColors.accentText : AppColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: ConstrainedBox(
          // Cao tối thiểu như nhau để các hàng trông đều nhau
          constraints: const BoxConstraints(minHeight: 148),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: highlight ? AppColors.accentText : AppColors.textFaint),
                const SizedBox(height: 10),
                FittedBox(
                  // Số dài (vd "12.500.000đ") tự thu nhỏ thay vì xuống dòng
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: AppColors.textTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.3, color: AppColors.textFaint),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Khung trắng bo góc có tiêu đề.
class AdminCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const AdminCard({
    super.key,
    this.title,
    this.trailing,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// Lưới tự chia cột theo chiều rộng (điện thoại 1–2 cột, máy tính 3–5 cột).
/// Các ô trong CÙNG MỘT HÀNG luôn cao bằng nhau (theo ô cao nhất hàng đó).
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / minItemWidth).floor().clamp(1, 6).toInt();
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += cols) {
          final rowItems = children.sublist(start, (start + cols).clamp(0, children.length));
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(
            // IntrinsicHeight + stretch: mọi ô trong hàng kéo cao bằng ô cao nhất
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cols; i++) ...[
                    if (i > 0) SizedBox(width: spacing),
                    // Hàng cuối thiếu ô: chừa chỗ trống để các ô giữ cùng độ rộng
                    Expanded(child: i < rowItems.length ? rowItems[i] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      },
    );
  }
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String fmtDateTime(DateTime d) =>
    '${fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Hộp thoại nhập lý do (bắt buộc). Trả về lý do hoặc null nếu huỷ.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  List<String> quick = const [],
}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (quick.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final q in quick)
                      ActionChip(label: Text(q), onPressed: () => setState(() => c.text = q)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: c,
                maxLines: 3,
                maxLength: 300,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Lý do *', hintText: hint),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusError),
            onPressed: c.text.trim().isEmpty ? null : () => Navigator.of(context).pop(c.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}
