import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

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
}
