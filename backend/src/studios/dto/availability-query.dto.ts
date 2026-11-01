import { Type } from 'class-transformer';
import {
  IsDateString,
  Matches,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class AvailabilityQueryDto {
  @IsDateString({}, { message: 'date phải theo định dạng YYYY-MM-DD' })
  date: string;

  // Gói quyết định cả set (lịch riêng) lẫn thời lượng cần trống.
  @IsUUID('all', { message: 'package_id không hợp lệ' })
  package_id: string;

  // Để hiện giá đúng theo số người. Không gửi = số người đã gồm trong giá gói.
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  num_people?: number;

  // Dịch vụ thêm khách đang tick, dạng "id1,id2" -> chỉ trả giờ còn thợ rảnh, giá đã cộng dịch vụ
  @IsOptional()
  @Matches(/^[0-9a-f-]{36}(,[0-9a-f-]{36}){0,1}$/i, {
    message: 'addon_ids là tối đa 2 mã dịch vụ, cách nhau bằng dấu phẩy',
  })
  addon_ids?: string;
}
