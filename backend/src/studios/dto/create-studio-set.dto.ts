import { IsInt, IsNotEmpty, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateStudioSetDto {
  @IsNotEmpty({ message: 'Tên bối cảnh không được để trống' })
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @MaxLength(50)
  style_tag?: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  capacity: number;

  // Không dùng @IsUrl bắt buộc https vì môi trường dev có thể dùng URL local/mock.
  @IsNotEmpty({ message: 'avatar_url không được để trống — dùng làm ảnh index CLIP' })
  @IsString()
  avatar_url: string;
}
