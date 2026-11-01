import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsPositive,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';

export class QueryStudiosDto {
  @IsOptional()
  @IsString()
  keyword?: string;

  @IsOptional()
  @IsString()
  district?: string;

  @IsOptional()
  @IsString()
  style_tag?: string;

  @IsOptional()
  @Type(() => Number)
  @IsPositive()
  min_price?: number;

  @IsOptional()
  @Type(() => Number)
  @IsPositive()
  max_price?: number;

  @IsOptional()
  @Type(() => Number)
  @Min(1)
  @Max(5)
  min_rating?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit: number = 10;

  // Dịch vụ kèm theo, dạng "photographer" / "makeup" / "photographer,makeup":
  // studio phải đang bán dịch vụ đó VÀ có người đang làm vai trò đó.
  @IsOptional()
  @Matches(/^(photographer|makeup)(,(photographer|makeup))?$/, {
    message: 'services chỉ nhận photographer, makeup (cách nhau bằng dấu phẩy)',
  })
  services?: string;

  // Sắp xếp: rating = đánh giá cao trước (mặc định), newest = mới tham gia trước
  @IsOptional()
  @IsIn(['rating', 'newest'], { message: 'sort chỉ nhận rating hoặc newest' })
  sort?: 'rating' | 'newest';
}
