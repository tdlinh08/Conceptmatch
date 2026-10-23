import { IsEmail, IsNotEmpty, MinLength } from 'class-validator';

export class RegisterDto {
  @IsNotEmpty({ message: 'Họ tên không được để trống' })
  full_name: string;

  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @MinLength(8, { message: 'Mật khẩu tối thiểu 8 ký tự' })
  password: string;
}
