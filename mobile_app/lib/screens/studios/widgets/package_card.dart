import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/studio_detail_model.dart';

// Thẻ gói thuê + khung giờ mở cửa/phụ thu — dùng chung cho màn Chi tiết studio
// và màn Chi tiết bối cảnh.

/// Thẻ một gói thuê; bấm vào để sang màn Đặt lịch với gói này được chọn sẵn.
class PackageCard extends StatelessWidget {
  final RentalPackageModel package;
  final VoidCallback onTap;

  const PackageCard({super.key, required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = package;
    final peopleText = p.extraPersonFee > 0
        ? 'Gồm ${p.includedPeople} người · +${Formatters.vnd(p.extraPersonFee)}/người thêm · tối đa ${p.maxPeople}'
        : 'Tối đa ${p.maxPeople} người';

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.duration(p.durationMinutes),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      peopleText,
                      style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textBody),
                    ),
                    if (p.description != null && p.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.description!.trim(),
                        style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textFaint),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Formatters.vnd(p.price),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTitle,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giờ mở cửa + phụ thu (thay cho bảng giá 4 ô cũ).
class OpeningInfo extends StatelessWidget {
  final StudioDetailModel detail;

  const OpeningInfo({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      detail.isOpen24h ? 'Mở cửa 24/7' : 'Mở cửa ${detail.openTime} – ${detail.closeTime} hằng ngày',
      if (detail.eveningSurchargePct > 0)
        'Phụ thu +${detail.eveningSurchargePct}% nếu bắt đầu từ ${detail.eveningStartTime}',
      if (detail.weekendSurchargePct > 0) 'Phụ thu +${detail.weekendSurchargePct}% thứ 7, chủ nhật',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.schedule_rounded, size: 14, color: AppColors.textFaint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textBody),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
