import { IsDateString, IsOptional, IsUUID } from 'class-validator';

export class AvailabilityQueryDto {
  @IsDateString({}, { message: 'date phải theo định dạng YYYY-MM-DD' })
  date: string;

  // Mở rộng so với API Contract gốc — xem giải thích trong studios.service.ts.
  // Nếu không truyền, mặc định lấy set đầu tiên đang hoạt động (is_active=true).
  @IsOptional()
  @IsUUID()
  set_id?: string;
}
