import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/** Gói thuê của một set: theo giờ, theo buổi, cả ngày... */
export class CreatePackageDto {
  @IsNotEmpty({ message: 'Tên gói không được để trống' })
  @MaxLength(100)
  name: string; // vd "Thuê theo giờ", "Gói 2 tiếng", "Nửa ngày"

  @IsOptional()
  @IsString()
  description?: string;

  @Type(() => Number)
  @IsInt({ message: 'duration_minutes phải là số nguyên (phút)' })
  @Min(30, { message: 'Gói ngắn nhất 30 phút' })
  @Max(1440, { message: 'Gói dài nhất 24 giờ' })
  duration_minutes: number; // phải chia hết cho 30 — kiểm tra trong service

  @Type(() => Number)
  @IsNumber(
    { maxDecimalPlaces: 0 },
    { message: 'price phải là số nguyên (VNĐ)' },
  )
  @Min(1000, { message: 'Giá gói tối thiểu 1.000đ' })
  price: number;

  @Type(() => Number)
  @IsInt()
  @Min(1, { message: 'Giá gói phải gồm ít nhất 1 người' })
  included_people: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber(
    { maxDecimalPlaces: 0 },
    { message: 'extra_person_fee phải là số nguyên (VNĐ)' },
  )
  @Min(0)
  extra_person_fee?: number; // không gửi = 0đ (không phụ thu theo người)

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  max_people: number; // >= included_people và <= sức chứa của set — kiểm tra trong service
}
