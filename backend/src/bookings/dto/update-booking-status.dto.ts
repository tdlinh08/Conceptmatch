import { IsEnum, IsOptional, IsString } from 'class-validator';
import { BookingStatus } from '@prisma/client';

// Studio Owner chỉ được chuyển sang các trạng thái này — KHÔNG bao gồm
// "pending" (trạng thái khởi tạo) hay "cancelled" (chỉ User tự huỷ qua DELETE).
const OWNER_UPDATABLE_STATUSES = [
  'confirmed',
  'rejected',
  'checked_in',
  'completed',
  'no_show',
] as const;

export class UpdateBookingStatusDto {
  @IsEnum(OWNER_UPDATABLE_STATUSES, {
    message: `status phải là 1 trong: ${OWNER_UPDATABLE_STATUSES.join(', ')}`,
  })
  status: (typeof OWNER_UPDATABLE_STATUSES)[number];

  // Bắt buộc khi status = "rejected" — được kiểm tra trong service, không phải
  // ở tầng DTO vì class-validator không hỗ trợ tốt validation điều kiện chéo field.
  @IsOptional()
  @IsString()
  cancel_reason?: string;
}

export type { BookingStatus };
