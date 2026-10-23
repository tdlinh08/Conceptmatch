import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Đánh dấu 1 route/controller là public — bỏ qua JwtAuthGuard toàn cục.
 * Dùng cho: /auth/register, /auth/login, /auth/google, /auth/refresh,
 * và sau này là các route xem public như GET /studios.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
