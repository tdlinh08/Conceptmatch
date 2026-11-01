import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Đặt lịch theo GÓI: gói xác định set + studio + thời lượng, nên không cần
 * gửi studio_id / set_id / end_time. Giá do backend tự tính (src/pricing),
 * app không gửi giá lên.
 */
export class CreateBookingDto {
  @IsUUID('all', { message: 'package_id không hợp lệ' })
  package_id: string;

  @IsDateString(
    {},
    {
      message:
        'start_time phải theo định dạng ISO 8601, vd: 2026-11-04T09:30:00',
    },
  )
  start_time: string;

  @Type(() => Number)
  @IsInt({ message: 'num_people phải là số nguyên' })
  @Min(1)
  @Max(100)
  num_people: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  special_note?: string;

  // Dịch vụ thêm (thợ ảnh / trang điểm), tối đa 1 dịch vụ mỗi vai trò
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(2)
  @IsUUID('all', {
    each: true,
    message: 'addon_ids chứa mã dịch vụ không hợp lệ',
  })
  addon_ids?: string[];
}
