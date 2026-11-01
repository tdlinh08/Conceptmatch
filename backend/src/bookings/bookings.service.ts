import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BookingStatus, Prisma, StaffRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ChatGateway } from '../conversations/chat.gateway';
import { CreateBookingDto } from './dto/create-booking.dto';
import { QueryBookingsDto } from './dto/query-bookings.dto';
import { QueryStudioBookingsDto } from './dto/query-studio-bookings.dto';
import { UpdateBookingStatusDto } from './dto/update-booking-status.dto';
import {
  addonLine,
  assertValidStart,
  hasFreeStaff,
  PricingError,
  quotePrice,
  withAddons,
} from '../pricing/pricing';
import {
  activeStaffCount,
  freeStaff,
  resolveAddons,
  ROLE_LABEL,
  roleBusyRanges,
} from '../studios/staff-rules';

const ACTIVE_BOOKING_STATUSES: BookingStatus[] = [
  'pending',
  'confirmed',
  'checked_in',
];

// State machine: Studio Owner chỉ được đi đúng các bước này, không được nhảy cóc
// (vd: không thể "completed" thẳng từ "pending" mà chưa qua "confirmed" -> "checked_in").
const ALLOWED_TRANSITIONS: Partial<Record<BookingStatus, BookingStatus[]>> = {
  pending: ['confirmed', 'rejected'],
  confirmed: ['checked_in', 'no_show'],
  checked_in: ['completed'],
};

// Dịch vụ thêm trong đơn + thợ được phân công (null khi chưa xác nhận)
const BOOKING_ADDON_SELECT = {
  id: true,
  name: true,
  role: true,
  unit: true,
  unit_price: true,
  quantity: true,
  amount: true,
  staff: {
    select: { id: true, full_name: true, avatar_url: true, phone: true },
  },
} satisfies Prisma.BookingAddonSelect;

type BookingAddonRow = Prisma.BookingAddonGetPayload<{
  select: typeof BOOKING_ADDON_SELECT;
}>;
const toAddonLine = (l: BookingAddonRow) => ({
  ...l,
  unit_price: Number(l.unit_price),
  quantity: Number(l.quantity),
  amount: Number(l.amount),
});

@Injectable()
export class BookingsService {
  constructor(
    private prisma: PrismaService,
    private chatGateway: ChatGateway,
  ) {}

  async create(userId: string, dto: CreateBookingDto) {
    // Gói -> set -> studio: một truy vấn lấy đủ thông tin để kiểm tra và tính giá
    const pkg = await this.prisma.rentalPackage.findFirst({
      where: {
        id: dto.package_id,
        is_active: true,
        set: { is_active: true, studio: { status: 'active' } },
      },
      include: { set: { include: { studio: true } } },
    });
    if (!pkg) {
      throw new NotFoundException(
        'Gói thuê không tồn tại hoặc đã ngừng nhận đặt',
      );
    }
    const set = pkg.set;
    const studio = set.studio;

    // Giờ bắt đầu hợp lệ + giờ kết thúc = bắt đầu + thời lượng gói; giá do backend tự tính
    // (KHÔNG nhận giá từ app — tránh bị sửa request để đặt giá rẻ).
    const startTime = new Date(dto.start_time);
    let endTime: Date;
    let roomQuote: ReturnType<typeof quotePrice>;
    try {
      endTime = assertValidStart({
        start: startTime,
        openTime: studio.open_time,
        closeTime: studio.close_time,
        durationMinutes: pkg.duration_minutes,
      });
      roomQuote = quotePrice(
        {
          price: Number(pkg.price),
          included_people: pkg.included_people,
          extra_person_fee: Number(pkg.extra_person_fee),
          max_people: pkg.max_people,
        },
        studio,
        dto.num_people,
        startTime,
      );
    } catch (err) {
      if (err instanceof PricingError)
        throw new BadRequestException(err.message);
      throw err;
    }

    // Dịch vụ thêm: snapshot tên + giá + số lượng vào đơn; tổng = phòng + dịch vụ
    const addons = await resolveAddons(this.prisma, studio.id, dto.addon_ids);
    const addonLines = addons.map((a) => {
      const line = addonLine(
        { price: Number(a.price), unit: a.unit },
        pkg.duration_minutes,
        dto.num_people,
      );
      return {
        addon_id: a.id,
        name: a.name,
        role: a.role,
        unit: a.unit,
        unit_price: Number(a.price),
        quantity: line.quantity,
        amount: line.amount,
      };
    });
    const quote = withAddons(
      roomQuote,
      addonLines.reduce((sum, l) => sum + l.amount, 0),
    );

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
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${set.id})::bigint)`;
      // Có dịch vụ thêm: khoá thêm theo (studio, vai trò) vì thợ dùng chung cho MỌI set
      // của studio. Luôn khoá set trước, vai trò sau, vai trò theo thứ tự cố định
      // (resolveAddons đã sắp) -> các giao dịch không bao giờ chờ vòng tròn (deadlock).
      for (const a of addons) {
        const key = `${studio.id}:${a.role}`;
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${key})::bigint)`;
      }

      const overlapping = await tx.booking.findFirst({
        where: {
          set_id: set.id,
          status: { in: ACTIVE_BOOKING_STATUSES },
          start_time: { lt: endTime },
          end_time: { gt: startTime },
        },
      });
      if (overlapping) {
        throw new ConflictException(
          'Khung giờ này vừa có người đặt, vui lòng chọn giờ khác',
        );
      }

      for (const a of addons) {
        const capacity = await activeStaffCount(tx, studio.id, a.role);
        const busy = await roleBusyRanges(
          tx,
          studio.id,
          a.role,
          startTime,
          endTime,
        );
        if (!hasFreeStaff(startTime, endTime, capacity, busy)) {
          throw new ConflictException(
            `Khung giờ này đã hết ${ROLE_LABEL[a.role]} rảnh, vui lòng chọn giờ khác hoặc bỏ dịch vụ`,
          );
        }
      }

      const created = await tx.booking.create({
        data: {
          user_id: userId,
          studio_id: studio.id,
          set_id: set.id,
          package_id: pkg.id,
          package_name: pkg.name,
          num_people: dto.num_people,
          start_time: startTime,
          end_time: endTime,
          base_amount: quote.base_amount,
          extra_people_amount: quote.extra_people_amount,
          surcharge_amount: quote.surcharge_amount,
          addons_amount: addonLines.length ? quote.addons_amount : null,
          total_amount: quote.total_amount,
          deposit_amount: quote.deposit_amount,
          special_note: dto.special_note,
          addons: { create: addonLines },
        },
        include: { addons: { select: BOOKING_ADDON_SELECT } },
      });
      return { ...created, addons: created.addons.map(toAddonLine) };
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
              images: {
                where: { is_cover: true },
                take: 1,
                select: { url: true },
              },
            },
          },
          set: { select: { name: true } },
          review: { select: { id: true } },
          addons: { select: BOOKING_ADDON_SELECT },
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
        package_name: b.package_name,
        num_people: b.num_people,
        start_time: b.start_time,
        end_time: b.end_time,
        total_amount: b.total_amount,
        deposit_amount: b.deposit_amount,
        status: b.status,
        has_review: b.review !== null,
        addons: b.addons.map(toAddonLine),
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
    const upcomingFirst =
      status !== undefined && ACTIVE_BOOKING_STATUSES.includes(status);

    const [data, total] = await this.prisma.$transaction([
      this.prisma.booking.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { start_time: upcomingFirst ? 'asc' : 'desc' },
        include: {
          studio: { select: { id: true, name: true } },
          set: { select: { id: true, name: true } },
          user: {
            select: {
              id: true,
              full_name: true,
              email: true,
              avatar_url: true,
            },
          },
          addons: { select: BOOKING_ADDON_SELECT },
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
        package_name: b.package_name,
        num_people: b.num_people,
        customer: b.user,
        start_time: b.start_time,
        end_time: b.end_time,
        total_amount: b.total_amount,
        deposit_amount: b.deposit_amount,
        status: b.status,
        special_note: b.special_note,
        cancel_reason: b.cancel_reason,
        addons: b.addons.map(toAddonLine),
        created_at: b.created_at,
      })),
      total,
    };
  }

  /**
   * Chi tiết 1 đơn cho màn "Chi tiết lịch hẹn" (khách) / "Chi tiết đơn" (chủ studio):
   * đủ lịch chụp, chi tiết giá, dịch vụ + thợ phụ trách, liên hệ studio, đánh giá.
   */
  async findOne(id: string, currentUser: { id: string }) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        studio: {
          select: {
            id: true,
            name: true,
            address: true,
            district: true,
            phone: true,
            owner_id: true,
            images: {
              where: { is_cover: true },
              take: 1,
              select: { url: true },
            },
          },
        },
        set: { select: { id: true, name: true, avatar_url: true } },
        user: {
          select: { id: true, full_name: true, email: true, avatar_url: true },
        },
        review: { select: { stars: true, comment: true, created_at: true } },
        addons: { select: BOOKING_ADDON_SELECT },
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

    const money = (v: Prisma.Decimal | null) => (v === null ? null : Number(v));
    return {
      id: booking.id,
      status: booking.status,
      start_time: booking.start_time,
      end_time: booking.end_time,
      package_name: booking.package_name,
      num_people: booking.num_people,
      special_note: booking.special_note,
      cancel_reason: booking.cancel_reason,
      created_at: booking.created_at,
      updated_at: booking.updated_at,
      base_amount: money(booking.base_amount),
      extra_people_amount: money(booking.extra_people_amount),
      surcharge_amount: money(booking.surcharge_amount),
      addons_amount: money(booking.addons_amount),
      total_amount: Number(booking.total_amount),
      deposit_amount: Number(booking.deposit_amount),
      // Chọn từng trường, KHÔNG trả owner_id ra ngoài
      studio: {
        id: booking.studio.id,
        name: booking.studio.name,
        address: booking.studio.address,
        district: booking.studio.district,
        phone: booking.studio.phone,
        cover_image: booking.studio.images[0]?.url ?? null,
      },
      set: booking.set,
      customer: booking.user,
      addons: booking.addons.map(toAddonLine),
      review: booking.review,
      has_review: booking.review !== null,
    };
  }

  async updateStatus(id: string, ownerId: string, dto: UpdateBookingStatusDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        studio: { select: { owner_id: true, name: true } },
        addons: { select: { id: true, role: true } },
      },
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
      throw new BadRequestException(
        'Cần nhập cancel_reason khi từ chối booking',
      );
    }

    const needsAssignment =
      dto.status === 'confirmed' && booking.addons.length > 0;
    const updated = await this.prisma.$transaction(async (tx) => {
      if (needsAssignment) {
        await this.assignStaff(tx, booking, dto.staff_assignments ?? []);
      }
      return tx.booking.update({
        where: { id },
        data: {
          status: dto.status,
          ...(dto.cancel_reason && { cancel_reason: dto.cancel_reason }),
        },
      });
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

  /**
   * Thợ đang rảnh cho từng dịch vụ của đơn — app chủ studio dùng để hiện danh sách
   * chọn người khi xác nhận (GET /bookings/:id/available-staff).
   */
  async availableStaff(id: string, ownerId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        studio: { select: { owner_id: true } },
        addons: { select: { id: true, name: true, role: true } },
      },
    });
    if (!booking) throw new NotFoundException('Booking không tồn tại');
    if (booking.studio.owner_id !== ownerId) {
      throw new ForbiddenException('Không phải owner của studio');
    }
    return Promise.all(
      booking.addons.map(async (line) => ({
        booking_addon_id: line.id,
        name: line.name,
        role: line.role,
        staff: await freeStaff(
          this.prisma,
          booking.studio_id,
          line.role,
          booking.start_time,
          booking.end_time,
          booking.id,
        ),
      })),
    );
  }

  /** Xác nhận đơn có dịch vụ thêm: mỗi vai trò phải được giao cho 1 người đang rảnh. */
  private async assignStaff(
    tx: Prisma.TransactionClient,
    booking: {
      id: string;
      studio_id: string;
      start_time: Date;
      end_time: Date;
      addons: { id: string; role: StaffRole }[];
    },
    assignments: { role: StaffRole; staff_id: string }[],
  ) {
    for (const line of booking.addons) {
      const assignment = assignments.find((a) => a.role === line.role);
      if (!assignment) {
        throw new BadRequestException(
          `Đơn có dịch vụ cần ${ROLE_LABEL[line.role]} — hãy chọn người phụ trách (staff_assignments)`,
        );
      }
      // Khoá theo người: 2 lần xác nhận cùng lúc không thể giao 1 người cho 2 đơn trùng giờ
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${assignment.staff_id})::bigint)`;
      const free = await freeStaff(
        tx,
        booking.studio_id,
        line.role,
        booking.start_time,
        booking.end_time,
        booking.id,
      );
      if (!free.some((s) => s.id === assignment.staff_id)) {
        throw new ConflictException(
          `Người được chọn không phải ${ROLE_LABEL[line.role]} của studio, đã nghỉ, hoặc đang bận giờ này`,
        );
      }
      await tx.bookingAddon.update({
        where: { id: line.id },
        data: { staff_id: assignment.staff_id },
      });
    }
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
}
