import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsPositive, IsString, Max, Min } from 'class-validator';

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
}
