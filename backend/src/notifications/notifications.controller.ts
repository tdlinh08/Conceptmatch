import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';

// Không @Roles: mọi tài khoản đã đăng nhập đều có hộp thông báo của mình.
@Controller('notifications')
export class NotificationsController {
  constructor(private notificationsService: NotificationsService) {}

  @Get()
  findMine(
    @CurrentUser('id') userId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    const safeLimit = Math.min(Math.max(Number(limit) || 20, 1), 50);
    return this.notificationsService.findMine(
      userId,
      Math.max(Number(page) || 1, 1),
      safeLimit,
    );
  }

  // Khai báo TRƯỚC ':id/read' cho rõ ràng (khác số đoạn đường dẫn nên không nhầm)
  @Get('unread-count')
  unreadCount(@CurrentUser('id') userId: string) {
    return this.notificationsService.unreadCount(userId);
  }

  @Patch('read-all')
  markAllRead(@CurrentUser('id') userId: string) {
    return this.notificationsService.markAllRead(userId);
  }

  @Patch(':id/read')
  markRead(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.notificationsService.markRead(id, userId);
  }
}
