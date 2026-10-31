import { IsOptional, IsUUID } from 'class-validator';
import { QueryBookingsDto } from './query-bookings.dto';

/** Lọc lịch đặt phía chủ studio: thêm studio_id (chủ có thể quản lý nhiều studio). */
export class QueryStudioBookingsDto extends QueryBookingsDto {
  @IsOptional()
  @IsUUID('all', { message: 'studio_id không hợp lệ' })
  studio_id?: string;
}
