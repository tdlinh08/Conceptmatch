import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

export class QueryAuditLogsDto {
  @IsOptional()
  @IsIn(['studio', 'user'], { message: 'target_type phải là studio hoặc user' })
  target_type?: 'studio' | 'user';

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
