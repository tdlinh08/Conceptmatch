import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Biểu đồ cột đơn giản, tự vẽ (không cần thư viện): mỗi cột 1 ngày / 1 tháng.
/// Giữ ngón tay / rê chuột lên cột để xem giá trị. Nhãn trục dưới tự thưa bớt khi nhiều cột.
class SimpleBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String Function(double) format; // định dạng giá trị (tooltip + trục)
  final double height;
  final Color color;

  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.format,
    this.height = 220,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 0.0 : values.reduce(math.max);
    final top = maxV <= 0 ? 1.0 : maxV;
    final n = values.length;
    // Hiện tối đa ~8 nhãn dưới trục để không chồng chữ
    final every = math.max(1, (n / 8).ceil());

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(format(maxV), style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
              const SizedBox(width: 6),
              const Expanded(child: Divider(height: 1, color: AppColors.outline)),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Tooltip(
                      message: '${labels[i]}: ${format(values[i])}',
                      triggerMode: TooltipTriggerMode.tap,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: n > 20 ? 1 : 3),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: values[i] <= 0 ? 0.01 : (values[i] / top).clamp(0.02, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: values[i] <= 0 ? AppColors.surfaceMuted : color,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineStrong),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: i % every == 0 || i == n - 1
                      ? Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: AppColors.textFaint),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
