import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { ROLES_KEY } from '../decorators/roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    // Route không khai báo @Roles(...) -> chỉ cần đăng nhập là đủ, không giới hạn role
    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    if (!requiredRoles.includes(user?.role)) {
      // Thay câu mặc định "Forbidden resource" bằng thông báo tiếng Việt dễ hiểu
      throw new ForbiddenException(
        'Tài khoản không có quyền thực hiện chức năng này',
      );
    }
    return true;
  }
}
