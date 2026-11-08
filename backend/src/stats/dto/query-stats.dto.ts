import { IsIn, IsOptional, IsUUID } from 'class-validator';

export const STAT_RANGES = ['7d', '30d', '12m'] as const;
export type StatRange = (typeof STAT_RANGES)[number];

export class QueryStatsDto {
  // 7d / 30d: theo ngày · 12m: theo tháng
  @IsOptional()
  @IsIn(STAT_RANGES, { message: 'range chỉ nhận 7d, 30d hoặc 12m' })
  range: StatRange = '30d';

  // Chỉ dùng ở thống kê của chủ studio: lọc 1 studio (bỏ trống = mọi studio của tôi)
  @IsOptional()
  @IsUUID('all', { message: 'studio_id không hợp lệ' })
  studio_id?: string;
}
