-- THÔNG BÁO (01/11/2026): thêm loại thông báo khách huỷ đơn + buổi chụp hoàn thành

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'booking_cancelled';
ALTER TYPE "NotificationType" ADD VALUE 'booking_completed';
