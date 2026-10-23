import { SetMetadata } from '@nestjs/common';
import { Role } from '@prisma/client';

export const ROLES_KEY = 'roles';

/**
 * Ví dụ dùng ở Studio module sau này:
 *   @Roles('studio_owner')
 *   @Post('studios')
 *   createStudio() {...}
 */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
