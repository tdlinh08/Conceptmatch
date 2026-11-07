import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/owner_studios_provider.dart';

/// Tab "Lịch đặt" của chủ studio.
/// Bước 15a: tổng quan số đơn chờ xác nhận theo từng studio.
/// Bước 15c: danh sách đơn, xác nhận + phân công thợ, từ chối, check-in, hoàn thành.
class OwnerBookingsScreen extends StatelessWidget {
  const OwnerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OwnerStudiosProvider>();
    final studios = provider.studios;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.fetchMine,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Text(
                'Lịch đặt',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfacePink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      '${provider.pendingBookingCount}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'đơn đang chờ bạn xác nhận',
                        style: TextStyle(fontSize: 15, color: AppColors.textBody),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final s in studios)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(s.name),
                  trailing: Text(
                    s.pendingBookingCount == 0 ? 'Không có đơn chờ' : '${s.pendingBookingCount} đơn chờ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: s.pendingBookingCount > 0 ? FontWeight.w600 : FontWeight.w400,
                      color: s.pendingBookingCount > 0 ? AppColors.accentText : AppColors.textFaint,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Màn quản lý đơn (xác nhận, phân công thợ, từ chối, check-in, hoàn thành) '
                'sẽ có ở bản cập nhật tiếp theo.',
                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
