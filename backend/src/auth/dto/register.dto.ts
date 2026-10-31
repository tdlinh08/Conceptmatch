import {
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  MaxLength,
  MinLength,
} from 'class-validator';

// Vai trò được TỰ đăng ký. "admin" cố ý không có ở đây: tài khoản quản trị
// chỉ tạo bằng seed / trực tiếp trong DB, không ai tự nâng quyền được.
export const SELF_REGISTER_ROLES = ['user', 'studio_owner'] as const;

export class RegisterDto {
  @IsNotEmpty({ message: 'Họ tên không được để trống' })
  @MaxLength(100)
  full_name: string;

  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @MinLength(8, { message: 'Mật khẩu tối thiểu 8 ký tự' })
  password: string;

  // Không gửi -> tài khoản khách hàng (giữ tương thích với app hiện tại)
  @IsOptional()
  @IsIn(SELF_REGISTER_ROLES, {
    message: 'role chỉ nhận user hoặc studio_owner',
  })
  role?: (typeof SELF_REGISTER_ROLES)[number];
}
