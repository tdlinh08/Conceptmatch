import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

export class QueryAuditLogsDto {
  @IsOptional()
  @IsIn(['studio', 'user', 'review'], { message: 'target_type phải là studio, user hoặc review' })
  target_type?: 'studio' | 'user' | 'review';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 20;
}
