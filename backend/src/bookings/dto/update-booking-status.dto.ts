import { Type } from 'class-transformer';
import {
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { BookingStatus, StaffRole } from '@prisma/client';

/** Phân công 1 người cho 1 vai trò của đơn (bắt buộc khi xác nhận đơn có dịch vụ thêm). */
export class StaffAssignmentDto {
  @IsEnum(StaffRole, { message: 'role phải là photographer hoặc makeup' })
  role: StaffRole;

  @IsUUID('all', { message: 'staff_id không hợp lệ' })
  staff_id: string;
}

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

  // Chỉ dùng khi status = "confirmed" và đơn có dịch vụ thêm
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => StaffAssignmentDto)
  staff_assignments?: StaffAssignmentDto[];
}

export type { BookingStatus };
