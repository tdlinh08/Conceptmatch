import { Transform } from 'class-transformer';
import { IsString, MaxLength, MinLength } from 'class-validator';

export const MESSAGE_MAX_LENGTH = 2000;

export class SendMessageDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString({ message: 'Nội dung tin nhắn phải là chuỗi' })
  @MinLength(1, { message: 'Tin nhắn không được để trống' })
  @MaxLength(MESSAGE_MAX_LENGTH, {
    message: `Tin nhắn tối đa ${MESSAGE_MAX_LENGTH} ký tự`,
  })
  content: string;
}
