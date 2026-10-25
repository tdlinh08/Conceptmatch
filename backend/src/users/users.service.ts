import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { promises as fs } from 'fs';
import { join } from 'path';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ChangePasswordDto } from './dto/change-password.dto';

const BCRYPT_COST = 12; // giống AuthService

/** Thư mục gốc chứa file người dùng tải lên (được phục vụ tĩnh tại /uploads, xem main.ts). */
export const UPLOADS_ROOT = join(process.cwd(), 'uploads');
export const AVATAR_DIR = join(UPLOADS_ROOT, 'avatars');

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  /** Dạng hồ sơ trả về cho app — KHÔNG bao giờ trả password_hash / refresh_token_hash. */
  private toProfile(user: {
    id: string;
    full_name: string;
    email: string;
    role: string;
    avatar_url: string | null;
    password_hash: string | null;
  }) {
    return {
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      role: user.role,
      avatar_url: user.avatar_url,
      // Tài khoản đăng nhập bằng Google không có mật khẩu -> app ẩn nút "Đổi mật khẩu".
      has_password: user.password_hash !== null,
    };
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { full_name: dto.full_name.trim() },
    });
    return this.toProfile(user);
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Tài khoản không tồn tại');

    if (!user.password_hash) {
      throw new BadRequestException(
        'Tài khoản đăng nhập bằng Google không có mật khẩu để đổi',
      );
    }

    // Trả 400 (không phải 401) khi sai mật khẩu hiện tại: 401 sẽ khiến app hiểu
    // nhầm là token hết hạn và tự đi làm mới token.
    const matches = await bcrypt.compare(dto.current_password, user.password_hash);
    if (!matches) {
      throw new BadRequestException('Mật khẩu hiện tại không đúng');
    }
    if (dto.current_password === dto.new_password) {
      throw new BadRequestException('Mật khẩu mới phải khác mật khẩu hiện tại');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { password_hash: await bcrypt.hash(dto.new_password, BCRYPT_COST) },
    });
    return { message: 'Đổi mật khẩu thành công' };
  }

  /** Gọi SAU KHI multer đã lưu file vào uploads/avatars/<filename>. */
  async updateAvatar(userId: string, filename: string) {
    const old = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { avatar_url: true },
    });

    const user = await this.prisma.user.update({
      where: { id: userId },
      // Lưu đường dẫn TƯƠNG ĐỐI: đổi IP/tên miền máy chủ không làm hỏng dữ liệu cũ.
      data: { avatar_url: `/uploads/avatars/${filename}` },
    });

    // Xoá ảnh cũ do chính hệ thống lưu (ảnh Google là link ngoài, không xoá).
    if (old?.avatar_url?.startsWith('/uploads/avatars/')) {
      const oldFile = join(AVATAR_DIR, old.avatar_url.replace('/uploads/avatars/', ''));
      await fs.unlink(oldFile).catch(() => undefined); // file đã mất thì bỏ qua
    }

    return this.toProfile(user);
  }
}
