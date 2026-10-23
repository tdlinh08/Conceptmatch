import { IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class CreateReviewDto {
  @IsUUID('4', { message: 'booking_id phải là UUID hợp lệ' })
  booking_id: string;

  @IsInt()
  @Min(1)
  @Max(5)
  stars: number;

  @IsOptional()
  @IsString()
  @MaxLength(500, { message: 'Nhận xét tối đa 500 ký tự' })
  comment?: string;
}
