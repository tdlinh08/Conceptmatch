import { Transform } from 'class-transformer';
import { IsEmail, IsNotEmpty } from 'class-validator';

// Email không phân biệt hoa/thường + bỏ khoảng trắng thừa (bàn phím điện thoại hay tự viết hoa chữ đầu)
const normalizeEmail = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

export class LoginDto {
  @Transform(normalizeEmail)
  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @IsNotEmpty({ message: 'Mật khẩu không được để trống' })
  password: string;
}
