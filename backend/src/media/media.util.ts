import { BadRequestException } from '@nestjs/common';
import { MulterOptions } from '@nestjs/platform-express/multer/interfaces/multer-options.interface';
import { diskStorage } from 'multer';
import { randomUUID } from 'crypto';
import { mkdirSync, promises as fs } from 'fs';
import { extname, join } from 'path';

/**
 * Tiện ích dùng chung cho mọi file ảnh người dùng tải lên (ảnh studio, ảnh set...).
 * Ảnh lưu trên đĩa tại backend/uploads/<thư mục con>/, phục vụ tĩnh ở /uploads (main.ts).
 * DB chỉ lưu đường dẫn TƯƠNG ĐỐI "/uploads/..." để đổi IP/tên miền không hỏng dữ liệu.
 */
export const UPLOADS_ROOT = join(process.cwd(), 'uploads');

const IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/** Cấu hình Multer: lưu vào uploads/<subdir>/ với tên ngẫu nhiên, chỉ nhận JPG/PNG/WEBP. */
export function imageUploadOptions(
  subdir: string,
  maxSizeMb = 8,
): MulterOptions {
  const dir = join(UPLOADS_ROOT, subdir);
  return {
    storage: diskStorage({
      destination: (_req, _file, cb) => {
        mkdirSync(dir, { recursive: true });
        cb(null, dir);
      },
      filename: (_req, file, cb) => {
        cb(
          null,
          `${randomUUID()}${extname(file.originalname).toLowerCase() || '.jpg'}`,
        );
      },
    }),
    limits: { fileSize: maxSizeMb * 1024 * 1024 },
    fileFilter: (_req, file, cb) => {
      if (!IMAGE_MIME_TYPES.includes(file.mimetype)) {
        cb(new BadRequestException('Chỉ nhận ảnh JPG, PNG hoặc WEBP'), false);
        return;
      }
      cb(null, true);
    },
  };
}

export const publicUrl = (subdir: string, filename: string) =>
  `/uploads/${subdir}/${filename}`;

/** Đường dẫn file trên đĩa của một URL "/uploads/..."; null nếu là link ngoài. */
export function localPathOf(url: string): string | null {
  if (!url.startsWith('/uploads/')) return null;
  const relative = url.slice('/uploads/'.length);
  if (relative.includes('..')) return null; // chặn đi ngược thư mục
  return join(UPLOADS_ROOT, relative);
}

/** Xoá file do hệ thống lưu; link ngoài hoặc file đã mất thì bỏ qua. */
export async function deleteLocalMedia(
  url: string | null | undefined,
): Promise<void> {
  if (!url) return;
  const path = localPathOf(url);
  if (path) await fs.unlink(path).catch(() => undefined);
}
