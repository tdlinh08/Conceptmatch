import { Type } from 'class-transformer';
import { IsEnum, IsPositive } from 'class-validator';
import { DayType, SlotType } from '@prisma/client';

export class UpsertPricingRuleDto {
  @IsEnum(SlotType, { message: 'slot_type phải là normal hoặc golden' })
  slot_type: SlotType;

  @IsEnum(DayType, { message: 'day_type phải là weekday, weekend hoặc holiday' })
  day_type: DayType;

  @Type(() => Number)
  @IsPositive({ message: 'price_per_hour phải lớn hơn 0' })
  price_per_hour: number;
}
