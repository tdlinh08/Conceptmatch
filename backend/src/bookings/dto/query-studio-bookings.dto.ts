import { IsIn, IsOptional, IsUUID } from 'class-validator';
import { QueryBookingsDto } from './query-bookings.dto';

/** Nhóm đơn theo tab ở app chủ studio. */
export const OWNER_BOOKING_GROUPS = ['pending', 'upcoming', 'past'] as const;
export type OwnerBookingGroup = (typeof OWNER_BOOKING_GROUPS)[number];

/** Lọc lịch đặt phía chủ studio: thêm studio_id (chủ có thể quản lý nhiều studio) + nhóm tab. */
export class QueryStudioBookingsDto extends QueryBookingsDto {
  @IsOptional()
  @IsUUID('all', { message: 'studio_id không hợp lệ' })
  studio_id?: string;

  // pending = chờ xác nhận · upcoming = đã xác nhận / đang chụp · past = đã kết thúc
  // (hoàn thành, khách không đến, từ chối, khách huỷ). Có "status" thì "status" được ưu tiên.
  @IsOptional()
  @IsIn(OWNER_BOOKING_GROUPS, { message: 'group phải là pending, upcoming hoặc past' })
  group?: OwnerBookingGroup;
}
