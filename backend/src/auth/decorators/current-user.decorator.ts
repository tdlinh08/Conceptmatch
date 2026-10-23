import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface AuthenticatedUser {
  id: string;
  email: string;
  role: string;
  full_name: string;
}

/**
 * Dùng: @CurrentUser() user, hoặc @CurrentUser('id') userId
 */
export const CurrentUser = createParamDecorator(
  (data: keyof AuthenticatedUser | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user: AuthenticatedUser = request.user;
    return data ? user?.[data] : user;
  },
);
