import { ReportStatus, ReportTargetType } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsEnum, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class CreateReportDto {
  @IsEnum(ReportTargetType, { message: 'target_type phải là studio hoặc review' })
  target_type: ReportTargetType;

  @IsUUID('all', { message: 'target_id không hợp lệ' })
  target_id: string;

  @IsNotEmpty({ message: 'Chọn lý do báo cáo' })
  @IsString()
  @MaxLength(100)
  reason: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  detail?: string;
}

export class QueryReportsDto {
  @IsOptional()
  @IsEnum(ReportStatus, { message: 'status phải là pending, resolved hoặc dismissed' })
  status?: ReportStatus;

  @IsOptional()
  @IsEnum(ReportTargetType)
  target_type?: ReportTargetType;

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

/** Xử lý báo cáo: ẩn đánh giá / gỡ studio / chỉ đánh dấu đã xử lý. */
export class ResolveReportDto {
  @IsIn(['hide_review', 'take_down', 'none'], { message: 'action phải là hide_review, take_down hoặc none' })
  action: 'hide_review' | 'take_down' | 'none';

  @IsNotEmpty({ message: 'Nhập ghi chú / lý do xử lý' })
  @IsString()
  @MaxLength(300)
  note: string;
}

export class DismissReportDto {
  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

export class HideReviewDto {
  @IsNotEmpty({ message: 'Nhập lý do ẩn đánh giá' })
  @IsString()
  @MaxLength(300)
  reason: string;
}
