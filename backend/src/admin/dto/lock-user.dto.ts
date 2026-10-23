import { IsNotEmpty, IsString } from 'class-validator';

export class LockUserDto {
  @IsNotEmpty({ message: 'Cần nhập lý do khoá tài khoản' })
  @IsString()
  reason: string;
}
