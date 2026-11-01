import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;
const HHMM_OR_24 = /^(([01]\d|2[0-3]):[0-5]\d|24:00)$/;

export class CreateStudioDto {
  @IsNotEmpty({ message: 'Tên studio không được để trống' })
  @MaxLength(150)
  name: string;

  @IsNotEmpty({ message: 'Địa chỉ không được để trống' })
  address: string;

  @IsNotEmpty({ message: 'Quận/huyện không được để trống' })
  @MaxLength(50)
  district: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsNotEmpty({ message: 'Số điện thoại không được để trống' })
  @MaxLength(20)
  phone: string;

  // ---- Giờ hoạt động (mặc định 08:00–22:00). Studio mở 24/7: "00:00" – "24:00" ----
  @IsOptional()
  @Matches(HHMM, { message: 'open_time phải dạng HH:mm, vd 08:00' })
  open_time?: string;

  @IsOptional()
  @Matches(HHMM_OR_24, {
    message: 'close_time phải dạng HH:mm (cho phép 24:00)',
  })
  close_time?: string;

  // ---- Phụ thu (%) — thay cho bảng giá 4 ô cũ ----
  @IsOptional()
  @Matches(HHMM, { message: 'evening_start_time phải dạng HH:mm, vd 18:00' })
  evening_start_time?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'evening_surcharge_pct phải là số nguyên' })
  @Min(0)
  @Max(200)
  evening_surcharge_pct?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'weekend_surcharge_pct phải là số nguyên' })
  @Min(0)
  @Max(200)
  weekend_surcharge_pct?: number;
}
