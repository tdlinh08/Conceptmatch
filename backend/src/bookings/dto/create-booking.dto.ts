import { IsDateString, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateBookingDto {
  @IsUUID('4', { message: 'studio_id phải là UUID hợp lệ' })
  studio_id: string;

  @IsUUID('4', { message: 'set_id phải là UUID hợp lệ' })
  set_id: string;

  @IsDateString({}, { message: 'start_time phải theo định dạng ISO 8601, vd: 2026-08-01T08:00:00' })
  start_time: string;

  @IsDateString({}, { message: 'end_time phải theo định dạng ISO 8601' })
  end_time: string;

  @IsOptional()
  @IsString()
  special_note?: string;
}
