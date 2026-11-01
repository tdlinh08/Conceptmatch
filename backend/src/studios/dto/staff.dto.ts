import { PartialType } from '@nestjs/mapped-types';
import { StaffRole } from '@prisma/client';
import {
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/** Thêm nhân sự của studio: thợ ảnh hoặc thợ trang điểm. */
export class CreateStaffDto {
  @IsNotEmpty({ message: 'Tên nhân sự không được để trống' })
  @MaxLength(100)
  full_name: string;

  @IsEnum(StaffRole, {
    message: 'role phải là photographer (thợ ảnh) hoặc makeup (trang điểm)',
  })
  role: StaffRole;

  @IsOptional()
  @MaxLength(20)
  phone?: string;

  // Ảnh đại diện: tải qua POST /studios/:id/media rồi gửi url vào đây
  @IsOptional()
  @IsString()
  avatar_url?: string;
}

/** Sửa nhân sự; nghỉ việc thì đặt is_active = false (không xoá vì còn lịch sử phân công). */
export class UpdateStaffDto extends PartialType(CreateStaffDto) {
  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}
