import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
} from '@nestjs/common';
import { AdminService } from './admin.service';
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
