import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BookingStatus, DayType, Prisma, SlotType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ChatGateway } from '../conversations/chat.gateway';
import { CreateBookingDto } from './dto/create-booking.dto';
import { QueryBookingsDto } from './dto/query-bookings.dto';
import { QueryStudioBookingsDto } from './dto/query-studio-bookings.dto';
import { UpdateBookingStatusDto } from './dto/update-booking-status.dto';

const OPENING_HOUR = 8;
const GOLDEN_HOUR = 18;
const CLOSING_HOUR = 22;
const DEPOSIT_RATIO = 0.3;

const ACTIVE_BOOKING_STATUSES: BookingStatus[] = ['pending', 'confirmed', 'checked_in'];

// State machine: Studio Owner chỉ được đi đúng các bước này, không được nhảy cóc
// (vd: không thể "completed" thẳng từ "pending" mà chưa qua "confirmed" -> "checked_in").
const ALLOWED_TRANSITIONS: Partial<Record<BookingStatus, BookingStatus[]>> = {
  pending: ['confirmed', 'rejected'],
  confirmed: ['checked_in', 'no_show'],
  checked_in: ['completed'],
};

@Injectable()
export class BookingsService {
  constructor(
    private prisma: PrismaService,
    private chatGateway: ChatGateway,
  ) {}

  async create(userId: string, dto: CreateBookingDto) {
    const startTime = new Date(dto.start_time);
    const endTime = new Date(dto.end_time);
    this.validateTimeRange(startTime, endTime);

    const set = await this.prisma.studioSet.findFirst({
      where: { id: dto.set_id, studio_id: dto.studio_id, is_active: true },
    });
    if (!set) {
      throw new NotFoundException('Studio hoặc Set không tồn tại');
    }

    const studio = await this.prisma.studio.findUnique({ where: { id: dto.studio_id } });
    if (!studio || studio.status !== 'active') {
      throw new NotFoundException('Studio hoặc Set không tồn tại');
    }

    const total_amount = await this.calculateTotalAmount(dto.studio_id, startTime, endTime);
    const deposit_amount = Math.round(total_amount * DEPOSIT_RATIO);

    return this.prisma.$transaction(async (tx) => {
      // Advisory lock theo set_id: serialize toàn bộ giao dịch tạo booking trên
      // CÙNG 1 set. Đây là điểm mấu chốt chống double-booking — xem giải thích
      // đầy đủ ở phần đầu file/README, tóm tắt: SELECT FOR UPDATE không đủ vì nó
      // chỉ khoá được dòng ĐÃ TỒN TẠI, trong khi race condition ở đây xảy ra giữa
      // 2 booking hoàn toàn MỚI được tạo gần như đồng thời (chưa có dòng nào để
      // khoá). pg_advisory_xact_lock khoá theo "khoá logic" (hash của set_id),
      // buộc transaction thứ 2 phải đợi transaction thứ 1 COMMIT/ROLLBACK xong
      // mới được tiếp tục — đảm bảo lúc kiểm tra trùng lịch luôn thấy dữ liệu
      // mới nhất. Lock tự động giải phóng khi transaction kết thúc.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${dto.set_id})::bigint)`;

      const overlapping = await tx.booking.findFirst({
        where: {
          set_id: dto.set_id,
          status: { in: ACTIVE_BOOKING_STATUSES },
          start_time: { lt: endTime },
          end_time: { gt: startTime },
        },
      });
      if (overlapping) {
        throw new ConflictException('Khung giờ đã bị đặt (double-booking)');
      }

      return tx.booking.create({
        data: {
          user_id: userId,
          studio_id: dto.studio_id,
          set_id: dto.set_id,
          start_time: startTime,
          end_time: endTime,
          total_amount,
          deposit_amount,
          special_note: dto.special_note,
        },
      });
    });
  }

  async findAllForUser(userId: string, query: QueryBookingsDto) {
    const { status, page, limit } = query;
    const where = { user_id: userId, ...(status && { status }) };

    const [data, total] = await this.prisma.$transaction([
      this.prisma.booking.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' },
        include: {
          studio: {
            select: {
              id: true,
              name: true,
              images: { where: { is_cover: true }, take: 1, select: { url: true } },
            },
          },
          set: { select: { name: true } },
          review: { select: { id: true } },
        },
      }),
      this.prisma.booking.count({ where }),
    ]);

    return {
      data: data.map((b) => ({
        id: b.id,
        studio_id: b.studio.id,
        studio_name: b.studio.name,
        // Bổ sung so với API Contract: ảnh bìa + tên set để hiển thị thẻ lịch hẹn,
        // has_review để app biết đơn đã hoàn thành nào còn được đánh giá.
        cover_image: b.studio.images[0]?.url ?? null,
        set_name: b.set.name,
        start_time: b.start_time,
        end_time: b.end_time,
        total_amount: b.total_amount,
        deposit_amount: b.deposit_amount,
        status: b.status,
        has_review: b.review !== null,
        created_at: b.created_at,
      })),
      total,
    };
  }

  /**
   * Lịch đặt của các studio thuộc chủ studio đang đăng nhập (bổ sung so với API
   * Contract — cần cho màn "Quản lý lịch đặt" của chủ studio).
   * Lịch còn hiệu lực (pending/confirmed/checked_in) xếp theo giờ chụp gần nhất trước;
   * các trạng thái đã kết thúc xếp mới nhất trước.
   */
  async findAllForOwner(ownerId: string, query: QueryStudioBookingsDto) {
    const { status, studio_id, page, limit } = query;
    const where: Prisma.BookingWhereInput = {
      studio: { owner_id: ownerId },
      ...(studio_id && { studio_id }),
      ...(status && { status }),
    };
    const upcomingFirst = status !== undefined && ACTIVE_BOOKING_STATUSES.includes(status);

    const [data, total] = await this.prisma.$transaction([
      this.prisma.booking.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { start_time: upcomingFirst ? 'asc' : 'desc' },
        include: {
          studio: { select: { id: true, name: true } },
          set: { select: { id: true, name: true } },
          user: { select: { id: true, full_name: true, email: true, avatar_url: true } },
        },
      }),
      this.prisma.booking.count({ where }),
    ]);

    return {
      data: data.map((b) => ({
        id: b.id,
        studio_id: b.studio.id,
        studio_name: b.studio.name,
        set_id: b.set.id,
        set_name: b.set.name,
        customer: b.user,
        start_time: b.start_time,
        end_time: b.end_time,
        total_amount: b.total_amount,
        deposit_amount: b.deposit_amount,
        status: b.status,
        special_note: b.special_note,
        cancel_reason: b.cancel_reason,
        created_at: b.created_at,
      })),
      total,
    };
  }

  async findOne(id: string, currentUser: { id: string }) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        studio: { select: { id: true, name: true, address: true, owner_id: true } },
        set: { select: { id: true, name: true } },
        user: { select: { id: true, full_name: true } },
      },
    });
    if (!booking) {
      throw new NotFoundException('Booking không tồn tại');
    }

    const isOwnerOfBooking = booking.user_id === currentUser.id;
    const isOwnerOfStudio = booking.studio.owner_id === currentUser.id;
    if (!isOwnerOfBooking && !isOwnerOfStudio) {
      throw new ForbiddenException('Không có quyền xem booking này');
    }

    return booking;
  }

  async updateStatus(id: string, ownerId: string, dto: UpdateBookingStatusDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: { studio: { select: { owner_id: true, name: true } } },
    });
    if (!booking) {
      throw new NotFoundException('Booking không tồn tại');
    }
    if (booking.studio.owner_id !== ownerId) {
      throw new ForbiddenException('Không phải owner của studio');
    }

    const allowedNext = ALLOWED_TRANSITIONS[booking.status] ?? [];
    if (!allowedNext.includes(dto.status)) {
      throw new BadRequestException(
        `Không thể chuyển từ trạng thái "${booking.status}" sang "${dto.status}"`,
      );
    }

    if (dto.status === 'rejected' && !dto.cancel_reason) {
      throw new BadRequestException('Cần nhập cancel_reason khi từ chối booking');
    }

    const updated = await this.prisma.booking.update({
      where: { id },
      data: {
        status: dto.status,
        ...(dto.cancel_reason && { cancel_reason: dto.cancel_reason }),
      },
    });

    // Đẩy thông báo real-time cho khách hàng biết trạng thái booking vừa đổi
    // (đúng theo API Contract WebSocket event "booking_status_changed").
    this.chatGateway.emitBookingStatusChanged(booking.user_id, {
      booking_id: booking.id,
      status: updated.status,
      studio_name: booking.studio.name,
    });

    return updated;
  }

  async remove(id: string, userId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: { studio: { select: { owner_id: true, name: true } } },
    });
    if (!booking) {
      throw new NotFoundException('Booking không tồn tại');
    }
    if (booking.user_id !== userId) {
      throw new ForbiddenException('Không phải chủ booking');
    }
    if (booking.status !== 'pending') {
      throw new ConflictException('Không thể huỷ booking đã xác nhận');
    }

    await this.prisma.booking.update({
      where: { id },
      data: { status: 'cancelled' },
    });

    // Đẩy thông báo real-time cho chủ studio biết khách vừa huỷ booking.
    this.chatGateway.emitBookingStatusChanged(booking.studio.owner_id, {
      booking_id: booking.id,
      status: 'cancelled',
      studio_name: booking.studio.name,
    });

    return { message: 'Đã huỷ đặt lịch thành công' };
  }

  // ---- Helper ----

  private validateTimeRange(start: Date, end: Date) {
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new BadRequestException('start_time hoặc end_time không hợp lệ');
    }
    if (start >= end) {
      throw new BadRequestException('start_time phải trước end_time');
    }
    if (start < new Date()) {
      throw new BadRequestException('Không thể đặt lịch cho thời điểm trong quá khứ');
    }
    if (start.toDateString() !== end.toDateString()) {
      throw new BadRequestException('Booking không được vắt qua nhiều ngày');
    }

    const startMinutes = start.getHours() * 60 + start.getMinutes();
    const endMinutes = end.getHours() * 60 + end.getMinutes();
    if (startMinutes < OPENING_HOUR * 60 || endMinutes > CLOSING_HOUR * 60) {
      throw new BadRequestException(
        `Studio chỉ nhận đặt lịch trong khung giờ ${OPENING_HOUR}h-${CLOSING_HOUR}h`,
      );
    }
  }

  private async calculateTotalAmount(
    studioId: string,
    start: Date,
    end: Date,
  ): Promise<number> {
    const dayType: DayType = [0, 6].includes(start.getDay()) ? 'weekend' : 'weekday';
    const pricingRules = await this.prisma.pricingRule.findMany({
      where: { studio_id: studioId, day_type: dayType },
    });

    const priceOf = (slotType: SlotType): number => {
      const rule = pricingRules.find((r) => r.slot_type === slotType);
      if (!rule) {
        throw new BadRequestException(
          `Studio chưa cấu hình giá cho khung giờ ${slotType}/${dayType}`,
        );
      }
      return Number(rule.price_per_hour);
    };

    let total = 0;
    const cursor = new Date(start);
    while (cursor < end) {
      const slotType: SlotType = cursor.getHours() < GOLDEN_HOUR ? 'normal' : 'golden';
      total += priceOf(slotType);
      cursor.setHours(cursor.getHours() + 1);
    }
    return total;
  }
}