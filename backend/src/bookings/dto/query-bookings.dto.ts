import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, Min } from 'class-validator';
import { BookingStatus } from '@prisma/client';

export class QueryBookingsDto {
  @IsOptional()
  @IsEnum(BookingStatus, { message: 'status không hợp lệ' })
  status?: BookingStatus;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit: number = 10;
}
