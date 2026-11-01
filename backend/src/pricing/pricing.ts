/**
 * LÕI TÍNH GIÁ VÀ GIỜ TRỐNG — hàm thuần (không gọi DB), dùng chung cho:
 *  - GET /studios/:id/availability  (hiện giá từng giờ bắt đầu cho khách xem)
 *  - POST /bookings                 (tính lại giá khi đặt — KHÔNG tin giá app gửi lên)
 * Tách riêng để viết unit test (pricing.spec.ts) và trình bày trong báo cáo.
 *
 * Công thức:
 *   giá gói theo số người = price + max(0, số người - included_people) * extra_person_fee
 *   % phụ thu            = (giờ bắt đầu >= evening_start_time ? evening_surcharge_pct : 0)
 *                        + (thứ 7 / chủ nhật ? weekend_surcharge_pct : 0)
 *   tiền phụ thu         = làm tròn đến 1.000đ (giá gói theo số người * % phụ thu / 100)
 *   tổng                 = giá gói theo số người + tiền phụ thu
 *   tiền cọc             = làm tròn đến 1.000đ (tổng * 30%)
 *
 * Dịch vụ thêm (thợ ảnh / trang điểm) — xem addonLine(): cộng SAU phụ thu,
 * tức phụ thu giờ tối / cuối tuần chỉ áp cho tiền thuê phòng:
 *   tổng có dịch vụ = tổng thuê phòng + Σ tiền dịch vụ;  cọc = 30% tổng có dịch vụ
 */

export const SLOT_STEP_MINUTES = 30; // giờ bắt đầu cách nhau 30 phút
export const DEPOSIT_RATIO = 0.3;
// Chỉ nhận đặt lịch trong N ngày tới (app hiện chọn được 14 ngày) — chặn đặt bừa năm sau
export const MAX_DAYS_AHEAD = 60;
const ROUND_TO = 1000;

export interface PackagePricing {
  price: number;
  included_people: number;
  extra_person_fee: number;
  max_people: number;
}

export interface StudioSurcharge {
  evening_start_time: string; // "HH:mm"
  evening_surcharge_pct: number;
  weekend_surcharge_pct: number;
}

export interface PriceQuote {
  base_amount: number;
  extra_people_amount: number;
  surcharge_pct: number;
  surcharge_amount: number;
  total_amount: number;
  deposit_amount: number;
}

/** Lỗi nghiệp vụ của phần tính giá — service đổi sang 400 Bad Request. */
export class PricingError extends Error {}

const roundMoney = (v: number) => Math.round(v / ROUND_TO) * ROUND_TO;

/** "08:30" -> 510. Chấp nhận "24:00" (= 1440) cho giờ đóng cửa. */
export function toMinutes(hhmm: string): number {
  const m = /^(\d{2}):(\d{2})$/.exec(hhmm);
  if (!m) throw new PricingError(`Giờ "${hhmm}" không đúng định dạng HH:mm`);
  const total = Number(m[1]) * 60 + Number(m[2]);
  if (Number(m[2]) > 59 || total > 24 * 60)
    throw new PricingError(`Giờ "${hhmm}" không hợp lệ`);
  return total;
}

/** 510 -> "08:30" */
export function toHHmm(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export const isWeekend = (date: Date) =>
  date.getDay() === 0 || date.getDay() === 6;

export function quotePrice(
  pkg: PackagePricing,
  studio: StudioSurcharge,
  numPeople: number,
  start: Date,
): PriceQuote {
  if (!Number.isInteger(numPeople) || numPeople < 1) {
    throw new PricingError('Số người phải là số nguyên từ 1 trở lên');
  }
  if (numPeople > pkg.max_people) {
    throw new PricingError(`Gói này nhận tối đa ${pkg.max_people} người`);
  }

  const base_amount = pkg.price;
  const extra_people_amount =
    Math.max(0, numPeople - pkg.included_people) * pkg.extra_person_fee;

  const startMinute = start.getHours() * 60 + start.getMinutes();
  const surcharge_pct =
    (startMinute >= toMinutes(studio.evening_start_time)
      ? studio.evening_surcharge_pct
      : 0) + (isWeekend(start) ? studio.weekend_surcharge_pct : 0);

  const subtotal = base_amount + extra_people_amount;
  const surcharge_amount = roundMoney((subtotal * surcharge_pct) / 100);
  const total_amount = subtotal + surcharge_amount;

  return {
    base_amount,
    extra_people_amount,
    surcharge_pct,
    surcharge_amount,
    total_amount,
    deposit_amount: roundMoney(total_amount * DEPOSIT_RATIO),
  };
}

export interface BusyRange {
  start: Date;
  end: Date;
}

// ---------------------------------------------------------------------------
// Dịch vụ thêm
// ---------------------------------------------------------------------------

export type AddonUnitType = 'per_booking' | 'per_hour' | 'per_person';

/** Số lượng tính tiền của 1 dịch vụ: 1 lượt / số giờ của gói / số người. */
export function addonQuantity(
  unit: AddonUnitType,
  durationMinutes: number,
  numPeople: number,
): number {
  switch (unit) {
    case 'per_hour':
      return Math.round((durationMinutes / 60) * 100) / 100;
    case 'per_person':
      return numPeople;
    default:
      return 1;
  }
}

export function addonLine(
  addon: { price: number; unit: AddonUnitType },
  durationMinutes: number,
  numPeople: number,
): { quantity: number; amount: number } {
  const quantity = addonQuantity(addon.unit, durationMinutes, numPeople);
  return { quantity, amount: roundMoney(addon.price * quantity) };
}

/** Cộng tiền dịch vụ vào báo giá thuê phòng, tính lại tiền cọc trên tổng mới. */
export function withAddons(
  quote: PriceQuote,
  addonsAmount: number,
): PriceQuote & { addons_amount: number } {
  const total_amount = quote.total_amount + addonsAmount;
  return {
    ...quote,
    addons_amount: addonsAmount,
    total_amount,
    deposit_amount: roundMoney(total_amount * DEPOSIT_RATIO),
  };
}

/**
 * Còn đủ người của một vai trò cho khung [start, end) không.
 * Quy tắc (an toàn, không bao giờ xếp trùng): số đơn ĐANG GIỮ CHỖ cần vai trò này
 * mà chồng lên khung phải < số người đang làm. Khi đó luôn còn ít nhất 1 người
 * rảnh trọn khung giờ (mỗi đơn chồng chiếm tối đa 1 người), nên lúc chủ studio
 * xác nhận đơn chắc chắn tìm được người để phân công.
 */
export function hasFreeStaff(
  start: Date,
  end: Date,
  capacity: number,
  busy: BusyRange[],
): boolean {
  const overlapping = busy.filter((b) => b.start < end && b.end > start).length;
  return overlapping < capacity;
}

/**
 * Các giờ bắt đầu hợp lệ trong một ngày cho gói dài `durationMinutes`:
 * nằm trong giờ mở cửa, đúng lưới 30 phút, kết thúc trước giờ đóng cửa,
 * không chồng lên booking đang giữ chỗ và không ở quá khứ.
 */
export function listStartTimes(params: {
  date: Date; // 00:00 của ngày cần xem (giờ máy chủ)
  openTime: string;
  closeTime: string;
  durationMinutes: number;
  busy: BusyRange[];
  // Mỗi vai trò khách đã chọn (thợ ảnh, trang điểm): số người + các đơn đang dùng vai trò đó
  roles?: { capacity: number; busy: BusyRange[] }[];
  now?: Date;
}): { start: Date; end: Date }[] {
  const open = toMinutes(params.openTime);
  const close = toMinutes(params.closeTime);
  const now = params.now ?? new Date();
  const result: { start: Date; end: Date }[] = [];

  // Bắt đầu từ mốc lưới 30 phút đầu tiên >= giờ mở cửa
  const first = Math.ceil(open / SLOT_STEP_MINUTES) * SLOT_STEP_MINUTES;
  for (
    let m = first;
    m + params.durationMinutes <= close;
    m += SLOT_STEP_MINUTES
  ) {
    const start = new Date(params.date);
    start.setHours(0, m, 0, 0);
    const end = new Date(start.getTime() + params.durationMinutes * 60_000);
    if (start <= now) continue;
    const overlaps = params.busy.some((b) => b.start < end && b.end > start);
    if (overlaps) continue;
    const staffOk = (params.roles ?? []).every((r) =>
      hasFreeStaff(start, end, r.capacity, r.busy),
    );
    if (staffOk) result.push({ start, end });
  }
  return result;
}

/** Kiểm tra một giờ bắt đầu cụ thể khi đặt lịch. Ném PricingError nếu sai. */
export function assertValidStart(params: {
  start: Date;
  openTime: string;
  closeTime: string;
  durationMinutes: number;
  now?: Date;
}): Date {
  const { start, durationMinutes } = params;
  if (Number.isNaN(start.getTime()))
    throw new PricingError('start_time không hợp lệ');
  const now = params.now ?? new Date();
  if (start <= now) {
    throw new PricingError('Không thể đặt lịch cho thời điểm trong quá khứ');
  }
  if (start.getTime() - now.getTime() > MAX_DAYS_AHEAD * 24 * 3600 * 1000) {
    throw new PricingError(
      `Chỉ nhận đặt lịch trong vòng ${MAX_DAYS_AHEAD} ngày tới`,
    );
  }
  if (start.getSeconds() !== 0 || start.getMilliseconds() !== 0) {
    throw new PricingError('Giờ bắt đầu phải tròn phút');
  }
  const startMinute = start.getHours() * 60 + start.getMinutes();
  if (startMinute % SLOT_STEP_MINUTES !== 0) {
    throw new PricingError('Giờ bắt đầu phải là mốc :00 hoặc :30');
  }
  const open = toMinutes(params.openTime);
  const close = toMinutes(params.closeTime);
  if (startMinute < open || startMinute + durationMinutes > close) {
    throw new PricingError(
      `Studio nhận khách ${params.openTime}–${params.closeTime}; gói ${durationMinutes} phút không vừa giờ bắt đầu này`,
    );
  }
  return new Date(start.getTime() + durationMinutes * 60_000);
}
