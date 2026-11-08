import { BookingStatus } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsDateString, IsEnum, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

/** Lọc đơn toàn sàn (admin, chỉ xem). */
export class QueryAdminBookingsDto {
  @IsOptional()
  @IsEnum(BookingStatus, { message: 'status không hợp lệ' })
  status?: BookingStatus;

  @IsOptional()
  @IsUUID('all', { message: 'studio_id không hợp lệ' })
  studio_id?: string;

  @IsOptional()
  @IsUUID('all', { message: 'user_id không hợp lệ' })
  user_id?: string;

  // Tên / email khách hoặc tên studio
  @IsOptional()
  @IsString()
  @MaxLength(100)
  keyword?: string;

  // Lọc theo NGÀY CHỤP (YYYY-MM-DD, giờ VN)
  @IsOptional()
  @IsDateString({}, { message: 'from phải là ngày YYYY-MM-DD' })
  from?: string;

  @IsOptional()
  @IsDateString({}, { message: 'to phải là ngày YYYY-MM-DD' })
  to?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 20;
}
