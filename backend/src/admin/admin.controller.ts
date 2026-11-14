import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { QueryAdminStudiosDto } from './dto/query-admin-studios.dto';
import { QueryAuditLogsDto } from './dto/query-audit-logs.dto';
import { QueryAdminBookingsDto } from './dto/query-admin-bookings.dto';
import { RejectStudioDto } from './dto/reject-studio.dto';
import { QueryUsersDto } from './dto/query-users.dto';
import { LockUserDto } from './dto/lock-user.dto';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Roles('admin')
@Controller('admin')
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Get('studios/pending')
  findPendingStudios(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.adminService.findPendingStudios(
      Number(page) || 1,
      Number(limit) || 10,
    );
  }

  /** Mọi studio (lọc status, keyword) + số lượng theo trạng thái. */
  @Get('studios')
  findStudios(@Query() query: QueryAdminStudiosDto) {
    return this.adminService.findStudios(query);
  }

  @Get('studios/:id')
  findStudio(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.findStudio(id);
  }

  /** Gỡ studio đang hoạt động (kèm lý do). */
  @Patch('studios/:id/take-down')
  takeDownStudio(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: RejectStudioDto,
  ) {
    return this.adminService.takeDownStudio(id, adminId, dto);
  }

  /**
   * Tạo lại vector AI cho MỌI bối cảnh đang hoạt động (ảnh đại diện + ảnh album chưa có vector)
   * rồi dựng lại chỉ mục FAISS. Dùng khi: AI service tắt lúc duyệt studio, sau khi nhập dữ liệu mẫu.
   */
  @Post('ai/reindex')
  reindexAi() {
    return this.adminService.reindexAi();
  }

  @Get('audit-logs')
  findAuditLogs(@Query() query: QueryAuditLogsDto) {
    return this.adminService.findAuditLogs(query);
  }

  @Patch('studios/:id/approve')
  approveStudio(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
  ) {
    return this.adminService.approveStudio(id, adminId);
  }

  @Patch('studios/:id/reject')
  rejectStudio(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: RejectStudioDto,
  ) {
    return this.adminService.rejectStudio(id, adminId, dto);
  }

  @Get('users')
  findUsers(@Query() query: QueryUsersDto) {
    return this.adminService.findUsers(query);
  }

  @Get('users/:id')
  findUser(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.findUser(id);
  }

  /** Mọi đơn đặt trên sàn — chỉ xem. */
  @Get('bookings')
  findBookings(@Query() query: QueryAdminBookingsDto) {
    return this.adminService.findBookings(query);
  }

  @Patch('users/:id/lock')
  lockUser(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: LockUserDto,
  ) {
    return this.adminService.lockUser(id, adminId, dto);
  }

  // Bổ sung so với API Contract gốc — xem giải thích ở đầu phần trao đổi.
  @Patch('users/:id/unlock')
  unlockUser(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
  ) {
    return this.adminService.unlockUser(id, adminId);
  }

  @Get('dashboard')
  getDashboard() {
    return this.adminService.getDashboard();
  }
}
