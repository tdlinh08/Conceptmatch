import { PartialType } from '@nestjs/mapped-types';
import { IsBoolean, IsOptional } from 'class-validator';
import { CreateStudioSetDto } from './create-studio-set.dto';

/** Sửa set: mọi trường đều tuỳ chọn, thêm is_active để ẩn/hiện set (không xoá vì còn lịch sử booking). */
export class UpdateStudioSetDto extends PartialType(CreateStudioSetDto) {
  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}
