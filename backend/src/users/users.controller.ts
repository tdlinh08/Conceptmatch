import {
  BadRequestException,
  Body,
  Controller,
  Patch,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { randomUUID } from 'crypto';
import { mkdirSync } from 'fs';
import { extname } from 'path';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UsersService, AVATAR_DIR } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ChangePasswordDto } from './dto/change-password.dto';

const MAX_AVATAR_SIZE = 5 * 1024 * 1024; // 5MB
const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/**
 * Hồ sơ của CHÍNH người đang đăng nhập (mọi role). Bổ sung so với API Contract.
 * Không gắn @Roles(...) -> chỉ cần đăng nhập (JwtAuthGuard toàn cục).
 */
@Controller('users/me')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Patch()
  updateProfile(@CurrentUser('id') userId: string, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(userId, dto);
  }

  @Patch('password')
  changePassword(@CurrentUser('id') userId: string, @Body() dto: ChangePasswordDto) {
    return this.usersService.changePassword(userId, dto);
  }

  @Post('avatar')
  @UseInterceptors(
    FileInterceptor('avatar', {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          mkdirSync(AVATAR_DIR, { recursive: true }); // tự tạo thư mục lần đầu
          cb(null, AVATAR_DIR);
        },
        // Tên file ngẫu nhiên: không lộ tên gốc, không trùng, và URL mới mỗi lần
        // đổi ảnh nên app không bị dính ảnh cũ trong bộ nhớ đệm.
        filename: (_req, file, cb) => {
          cb(null, `${randomUUID()}${extname(file.originalname).toLowerCase() || '.jpg'}`);
        },
      }),
      limits: { fileSize: MAX_AVATAR_SIZE },
      fileFilter: (_req, file, cb) => {
        if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
          cb(new BadRequestException('Chỉ nhận ảnh JPG, PNG hoặc WEBP'), false);
          return;
        }
        cb(null, true);
      },
    }),
  )
  uploadAvatar(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('Chưa chọn ảnh');
    return this.usersService.updateAvatar(userId, file.filename);
  }
}
