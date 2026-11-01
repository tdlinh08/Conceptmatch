import { PartialType } from '@nestjs/mapped-types';
import { AddonUnit, StaffRole } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

/** Dịch vụ thêm khách tự chọn khi đặt lịch, mỗi dịch vụ cần 1 người thuộc [role]. */
export class CreateAddonDto {
  @IsEnum(StaffRole, {
    message: 'role phải là photographer (thợ ảnh) hoặc makeup (trang điểm)',
  })
  role: StaffRole;

  @IsNotEmpty({ message: 'Tên dịch vụ không được để trống' })
  @MaxLength(100)
  name: string; // vd "Thợ ảnh chụp", "Trang điểm cô dâu"

  @IsOptional()
  @IsString()
  description?: string;

  @Type(() => Number)
  @IsNumber(
    { maxDecimalPlaces: 0 },
    { message: 'price phải là số nguyên (VNĐ)' },
  )
  @Min(1000, { message: 'Giá dịch vụ tối thiểu 1.000đ' })
  price: number;

  @IsEnum(AddonUnit, {
    message:
      'unit phải là per_booking (theo lượt), per_hour (theo giờ) hoặc per_person (theo người)',
  })
  unit: AddonUnit;
}

export class UpdateAddonDto extends PartialType(CreateAddonDto) {
  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}
