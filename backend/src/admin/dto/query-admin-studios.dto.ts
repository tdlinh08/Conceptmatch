import { StudioStatus } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

/** Lọc studio ở trang admin: theo trạng thái + từ khoá (tên studio, quận, tên / email chủ). */
export class QueryAdminStudiosDto {
  @IsOptional()
  @IsEnum(StudioStatus, { message: 'status phải là pending, active hoặc rejected' })
  status?: StudioStatus;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  keyword?: string;

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
