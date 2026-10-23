import { IsNotEmpty, IsString } from 'class-validator';

export class RejectStudioDto {
  @IsNotEmpty({ message: 'Cần nhập lý do từ chối' })
  @IsString()
  reason: string;
}
