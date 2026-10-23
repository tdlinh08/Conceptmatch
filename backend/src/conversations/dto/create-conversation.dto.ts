import { IsUUID } from 'class-validator';

export class CreateConversationDto {
  @IsUUID('4', { message: 'studio_id phải là UUID hợp lệ' })
  studio_id: string;
}
