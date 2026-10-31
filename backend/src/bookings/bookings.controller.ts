import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { QueryBookingsDto } from './dto/query-bookings.dto';
import { QueryStudioBookingsDto } from './dto/query-studio-bookings.dto';
import { UpdateBookingStatusDto } from './dto/update-booking-status.dto';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../auth/decorators/current-user.decorator';

@Controller('bookings')
export class BookingsController {
  constructor(private bookingsService: BookingsService) {}

  @Roles('user')
  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateBookingDto) {
    return this.bookingsService.create(userId, dto);
  }

  @Roles('user')
  @Get()
  findAll(@CurrentUser('id') userId: string, @Query() query: QueryBookingsDto) {
    return this.bookingsService.findAllForUser(userId, query);
  }

  // Chủ studio xem lịch đặt của các studio mình. Khai báo TRƯỚC @Get(':id')
  // để "studio" không bị hiểu là một :id.
  @Roles('studio_owner')
  @Get('studio')
  findAllForOwner(
    @CurrentUser('id') ownerId: string,
    @Query() query: QueryStudioBookingsDto,
  ) {
    return this.bookingsService.findAllForOwner(ownerId, query);
  }

  // Không @Roles(...) -> chỉ cần đăng nhập (User đặt hoặc Owner của studio đều
  // xem được), việc phân biệt ai được xem nằm trong logic service.
  @Get(':id')
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.bookingsService.findOne(id, user);
  }

  @Roles('studio_owner')
  @Patch(':id/status')
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: UpdateBookingStatusDto,
  ) {
    return this.bookingsService.updateStatus(id, ownerId, dto);
  }

  @Roles('user')
  @Delete(':id')
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.bookingsService.remove(id, userId);
  }
}
