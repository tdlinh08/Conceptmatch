import { PartialType } from '@nestjs/mapped-types';
import { IsBoolean, IsOptional } from 'class-validator';
import { CreatePackageDto } from './create-package.dto';

/** Sửa gói. Không xoá gói đã có người đặt -> ẩn/hiện bằng is_active. */
export class UpdatePackageDto extends PartialType(CreatePackageDto) {
  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}
