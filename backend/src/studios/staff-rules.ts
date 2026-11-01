import { BadRequestException } from '@nestjs/common';
import { BookingStatus, Prisma, StaffRole } from '@prisma/client';
import { BusyRange } from '../pricing/pricing';

/**
 * Quy tắc nhân sự dùng chung cho: xem giờ trống, đặt lịch, phân công khi xác nhận.
 * Nhận `db` là PrismaService hoặc client trong transaction (tx) để dùng được cả hai nơi.
 */
type Db = Prisma.TransactionClient;

// Đơn còn giữ chỗ (phòng + thợ). Đơn bị từ chối / huỷ / xong thì trả lại.
export const HOLDING_STATUSES: BookingStatus[] = [
  'pending',
  'confirmed',
  'checked_in',
];

export const ROLE_LABEL: Record<StaffRole, string> = {
  photographer: 'thợ ảnh',
  makeup: 'thợ trang điểm',
};

export type ResolvedAddon = Prisma.AddonServiceGetPayload<object>;

/**
 * Kiểm tra danh sách dịch vụ khách chọn: thuộc studio, đang bán, mỗi vai trò tối đa 1 dịch vụ.
 * Trả về theo thứ tự vai trò (cố định) để khoá theo cùng thứ tự -> tránh deadlock.
 */
export async function resolveAddons(
  db: Db,
  studioId: string,
  addonIds: string[] | undefined,
): Promise<ResolvedAddon[]> {
  const ids = [...new Set(addonIds ?? [])];
  if (ids.length === 0) return [];

  const addons = await db.addonService.findMany({
    where: { id: { in: ids }, studio_id: studioId, is_active: true },
  });
  if (addons.length !== ids.length) {
    throw new BadRequestException(
      'Dịch vụ thêm không tồn tại hoặc đã ngừng cung cấp',
    );
  }
  const roles = addons.map((a) => a.role);
  if (new Set(roles).size !== roles.length) {
    throw new BadRequestException('Mỗi loại thợ chỉ chọn được 1 dịch vụ');
  }
  return addons.sort((a, b) => a.role.localeCompare(b.role));
}

/** Số người đang làm của từng vai trò trong studio. */
export async function activeStaffCount(
  db: Db,
  studioId: string,
  role: StaffRole,
) {
  return db.staffMember.count({
    where: { studio_id: studioId, role, is_active: true },
  });
}

/** Các đơn đang giữ chỗ trong [from, to) có dùng vai trò [role] (mọi set của studio). */
export async function roleBusyRanges(
  db: Db,
  studioId: string,
  role: StaffRole,
  from: Date,
  to: Date,
  excludeBookingId?: string,
): Promise<BusyRange[]> {
  const rows = await db.booking.findMany({
    where: {
      studio_id: studioId,
      status: { in: HOLDING_STATUSES },
      start_time: { lt: to },
      end_time: { gt: from },
      addons: { some: { role } },
      ...(excludeBookingId && { id: { not: excludeBookingId } }),
    },
    select: { start_time: true, end_time: true },
  });
  return rows.map((r) => ({ start: r.start_time, end: r.end_time }));
}

/** Người của [role] đang rảnh TRỌN khung [start, end) — dùng khi chủ studio phân công. */
export async function freeStaff(
  db: Db,
  studioId: string,
  role: StaffRole,
  start: Date,
  end: Date,
  excludeBookingId?: string,
) {
  const staff = await db.staffMember.findMany({
    where: { studio_id: studioId, role, is_active: true },
    orderBy: { full_name: 'asc' },
    select: {
      id: true,
      full_name: true,
      role: true,
      avatar_url: true,
      phone: true,
    },
  });
  const busyRows = await db.bookingAddon.findMany({
    where: {
      staff_id: { in: staff.map((s) => s.id) },
      booking: {
        status: { in: HOLDING_STATUSES },
        start_time: { lt: end },
        end_time: { gt: start },
        ...(excludeBookingId && { id: { not: excludeBookingId } }),
      },
    },
    select: { staff_id: true },
  });
  const busyIds = new Set(busyRows.map((r) => r.staff_id));
  return staff.filter((s) => !busyIds.has(s.id));
}
