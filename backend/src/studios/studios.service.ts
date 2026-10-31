import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BookingStatus, DayType, Prisma, SlotType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStudioDto } from './dto/create-studio.dto';
import { UpdateStudioDto } from './dto/update-studio.dto';
import { QueryStudiosDto } from './dto/query-studios.dto';
import { CreateStudioSetDto } from './dto/create-studio-set.dto';
import { AvailabilityQueryDto } from './dto/availability-query.dto';
import { UpsertPricingRuleDto } from './dto/upsert-pricing-rule.dto';
import { UpdateStudioSetDto } from './dto/update-studio-set.dto';
import { AiService } from '../ai/ai.service';
import { deleteLocalMedia } from '../media/media.util';

// Khung giờ hoạt động cố định theo đúng SRS: 8h-18h (normal), 18h-22h (golden).
// Nếu sau này cần cấu hình linh hoạt theo từng studio, tách ra thành field DB riêng.
const OPENING_HOUR = 8;
const GOLDEN_HOUR = 18;
const CLOSING_HOUR = 22;

// Trạng thái booking coi là "đang giữ chỗ", chặn slot đó không cho đặt tiếp
const ACTIVE_BOOKING_STATUSES: BookingStatus[] = ['pending', 'confirmed', 'checked_in'];

// Trường trả về cho set — KHÔNG có clip_embedding (Unsupported, Prisma không đọc được)
const SET_SELECT = {
  id: true,
  name: true,
  description: true,
  style_tag: true,
  capacity: true,
  avatar_url: true,
  is_active: true,
} satisfies Prisma.StudioSetSelect;

// Các trường dùng chung cho thẻ studio (danh sách, nổi bật, gợi ý) — khai báo
// MỘT lần để 3 API trả về cùng một dạng dữ liệu, thêm trường chỉ cần sửa ở đây.
const STUDIO_SUMMARY_SELECT = {
  id: true,
  name: true,
  district: true,
  avg_rating: true,
  images: { where: { is_cover: true }, take: 1, select: { url: true } },
  // Lấy đúng 1 dòng giá rẻ nhất -> hiển thị "Từ ...đ / giờ" trên thẻ
  pricing_rules: {
    orderBy: { price_per_hour: 'asc' },
    take: 1,
    select: { price_per_hour: true },
  },
} satisfies Prisma.StudioSelect;

type StudioSummaryRow = Prisma.StudioGetPayload<{ select: typeof STUDIO_SUMMARY_SELECT }>;

@Injectable()
export class StudiosService {
  constructor(
    private prisma: PrismaService,
    private aiService: AiService,
  ) {}

  async findAll(query: QueryStudiosDto) {
    const { keyword, district, style_tag, min_price, max_price, min_rating, page, limit } = query;

    const where: Prisma.StudioWhereInput = {
      status: 'active', // Public chỉ thấy studio đã được Admin duyệt
      ...(keyword && {
        name: { contains: keyword, mode: 'insensitive' },
      }),
      ...(district && { district }),
      ...(style_tag && {
        sets: { some: { style_tag, is_active: true } },
      }),
      ...(min_rating !== undefined && { avg_rating: { gte: min_rating } }),
      ...((min_price !== undefined || max_price !== undefined) && {
        pricing_rules: {
          some: {
            ...(min_price !== undefined && { price_per_hour: { gte: min_price } }),
            ...(max_price !== undefined && { price_per_hour: { lte: max_price } }),
          },
        },
      }),
    };

    const [data, total] = await this.prisma.$transaction([
      this.prisma.studio.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' },
        select: STUDIO_SUMMARY_SELECT,
      }),
      this.prisma.studio.count({ where }),
    ]);

    return {
      data: data.map((s) => this.toSummary(s)),
      total,
      page,
      limit,
    };
  }

  async findOne(id: string) {
    // Khách chỉ xem được studio đã duyệt. Chủ studio xem studio của mình
    // (kể cả đang chờ duyệt / bị từ chối) qua GET /studios/mine/:id.
    const studio = await this.prisma.studio.findFirst({
      where: { id, status: 'active' },
      include: {
        images: { orderBy: { sort_order: 'asc' } },
        sets: { where: { is_active: true } },
        pricing_rules: true,
      },
    });

    if (!studio) {
      throw new NotFoundException('Studio không tồn tại');
    }

    return studio;
  }

  async create(ownerId: string, dto: CreateStudioDto) {
    return this.prisma.studio.create({
      data: {
        ...dto,
        owner_id: ownerId,
        status: 'pending', // Luôn tạo ở trạng thái chờ duyệt, Admin phê duyệt sau
      },
    });
  }

  async update(id: string, ownerId: string, dto: UpdateStudioDto) {
    const studio = await this.ensureOwnership(id, ownerId);

    return this.prisma.studio.update({
      where: { id },
      data: {
        ...dto,
        // Bị từ chối -> chủ studio sửa lại thông tin -> tự động gửi duyệt lại
        ...(studio.status === 'rejected' && { status: 'pending', reject_reason: null }),
      },
    });
  }

  // ===========================================================================
  // Dành cho chủ studio (studio_owner)
  // ===========================================================================

  /** Danh sách studio của chính chủ, mọi trạng thái, kèm số liệu nhanh. */
  async findMine(ownerId: string) {
    const studios = await this.prisma.studio.findMany({
      where: { owner_id: ownerId },
      orderBy: { created_at: 'desc' },
      select: {
        ...STUDIO_SUMMARY_SELECT,
        address: true,
        status: true,
        reject_reason: true,
        review_count: true,
        _count: {
          select: {
            sets: { where: { is_active: true } },
            images: true,
            bookings: { where: { status: 'pending' } },
          },
        },
      },
    });

    return studios.map((s) => ({
      ...this.toSummary(s),
      address: s.address,
      status: s.status,
      reject_reason: s.reject_reason,
      review_count: s.review_count,
      set_count: s._count.sets,
      image_count: s._count.images,
      pending_booking_count: s._count.bookings,
    }));
  }

  /** Chi tiết studio của chính chủ: gồm cả set đang ẩn, trạng thái duyệt, lý do từ chối. */
  async findMineOne(id: string, ownerId: string) {
    await this.ensureOwnership(id, ownerId);
    return this.prisma.studio.findUnique({
      where: { id },
      include: {
        images: { orderBy: { sort_order: 'asc' } },
        sets: { orderBy: { created_at: 'asc' }, select: SET_SELECT },
        pricing_rules: true,
      },
    });
  }

  /** Thêm nhiều ảnh studio. Studio chưa có ảnh bìa -> ảnh đầu tiên thành ảnh bìa. */
  async addImages(studioId: string, ownerId: string, urls: string[]) {
    await this.ensureOwnership(studioId, ownerId);
    if (urls.length === 0) throw new BadRequestException('Chưa chọn ảnh nào');

    const [hasCover, last] = await Promise.all([
      this.prisma.studioImage.count({ where: { studio_id: studioId, is_cover: true } }),
      this.prisma.studioImage.findFirst({
        where: { studio_id: studioId },
        orderBy: { sort_order: 'desc' },
        select: { sort_order: true },
      }),
    ]);
    const start = (last?.sort_order ?? -1) + 1;

    await this.prisma.studioImage.createMany({
      data: urls.map((url, i) => ({
        studio_id: studioId,
        url,
        sort_order: start + i,
        is_cover: hasCover === 0 && i === 0,
      })),
    });
    return this.findImages(studioId);
  }

  async setCoverImage(studioId: string, ownerId: string, imageId: string) {
    await this.ensureOwnership(studioId, ownerId);
    await this.ensureImage(studioId, imageId);

    await this.prisma.$transaction([
      this.prisma.studioImage.updateMany({
        where: { studio_id: studioId },
        data: { is_cover: false },
      }),
      this.prisma.studioImage.update({ where: { id: imageId }, data: { is_cover: true } }),
    ]);
    return this.findImages(studioId);
  }

  async deleteImage(studioId: string, ownerId: string, imageId: string) {
    await this.ensureOwnership(studioId, ownerId);
    const image = await this.ensureImage(studioId, imageId);

    await this.prisma.studioImage.delete({ where: { id: imageId } });
    await deleteLocalMedia(image.url);

    // Xoá đúng ảnh bìa -> lấy ảnh kế tiếp làm bìa để thẻ studio không bị trống ảnh
    if (image.is_cover) {
      const next = await this.prisma.studioImage.findFirst({
        where: { studio_id: studioId },
        orderBy: { sort_order: 'asc' },
      });
      if (next) {
        await this.prisma.studioImage.update({ where: { id: next.id }, data: { is_cover: true } });
      }
    }
    return this.findImages(studioId);
  }

  /** Sửa set. Đổi ảnh đại diện / ẩn-hiện set khi studio đang hoạt động -> cập nhật AI index. */
  async updateSet(studioId: string, setId: string, ownerId: string, dto: UpdateStudioSetDto) {
    const studio = await this.ensureOwnership(studioId, ownerId);
    const set = await this.prisma.studioSet.findFirst({
      where: { id: setId, studio_id: studioId },
      select: SET_SELECT,
    });
    if (!set) throw new NotFoundException('Bối cảnh (set) không tồn tại trong studio này');

    const avatarChanged = dto.avatar_url !== undefined && dto.avatar_url !== set.avatar_url;
    const activeChanged = dto.is_active !== undefined && dto.is_active !== set.is_active;

    const updated = await this.prisma.studioSet.update({
      where: { id: setId },
      data: dto,
      select: SET_SELECT,
    });

    if (avatarChanged) {
      await deleteLocalMedia(set.avatar_url);
      // Ảnh đổi -> vector cũ không còn đúng; xoá đi để set không bị tìm thấy bằng ảnh cũ
      await this.prisma.$executeRaw`
        UPDATE studio_sets SET clip_embedding = NULL WHERE id::text = ${setId}
      `;
    }

    let ai_warnings: string[] = [];
    if (studio.status === 'active') {
      if (avatarChanged || (activeChanged && updated.is_active)) {
        ai_warnings = await this.aiService.indexSets([setId]); // encode + reindex
      } else if (activeChanged) {
        const warning = await this.aiService.reindex(); // set bị ẩn -> loại khỏi index
        if (warning) ai_warnings = [warning];
      }
    }
    return { ...updated, ai_warnings };
  }

  async findSets(studioId: string) {
    await this.ensureStudioExists(studioId);

    return this.prisma.studioSet.findMany({
      where: { studio_id: studioId, is_active: true },
      orderBy: { created_at: 'asc' },
      select: SET_SELECT,
    });
  }

  async createSet(studioId: string, ownerId: string, dto: CreateStudioSetDto) {
    const studio = await this.ensureOwnership(studioId, ownerId);

    const set = await this.prisma.studioSet.create({
      data: { ...dto, studio_id: studioId },
      select: SET_SELECT,
    });

    // Studio đang chờ duyệt: chưa encode, Admin duyệt xong sẽ encode cả studio.
    // Studio đã hoạt động: encode ngay để set mới tìm được bằng ảnh.
    const ai_warnings =
      studio.status === 'active' ? await this.aiService.indexSets([set.id]) : [];
    return { ...set, ai_warnings };
  }

  async findReviews(studioId: string, page = 1, limit = 10) {
    await this.ensureStudioExists(studioId);

    const [data, total] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where: { studio_id: studioId },
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' },
        select: {
          id: true,
          stars: true,
          comment: true,
          created_at: true,
          user: { select: { full_name: true, avatar_url: true } },
        },
      }),
      this.prisma.review.count({ where: { studio_id: studioId } }),
    ]);

    return { data, total };
  }

  /**
   * Tính danh sách slot trống trong 1 ngày cho 1 set cụ thể của studio.
   *
   * LƯU Ý THIẾT KẾ (khác biệt so với API Contract gốc):
   * Booking gắn với set_id (mỗi set có lịch riêng), nhưng API Contract chỉ nhận
   * `date` mà không có `set_id`. Nếu không phân biệt set, 2 khách đặt 2 set khác
   * nhau cùng giờ sẽ bị tính nhầm là trùng lịch (double-booking giả).
   * -> Thêm set_id là query param TÙY CHỌN. Không truyền thì mặc định lấy
   *    set đầu tiên đang active của studio.
   */
  async getAvailability(studioId: string, query: AvailabilityQueryDto) {
    await this.ensureStudioExists(studioId);

    const targetSet = await this.resolveTargetSet(studioId, query.set_id);
    const date = new Date(`${query.date}T00:00:00`);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException('date không hợp lệ');
    }

    const dayType: DayType = [0, 6].includes(date.getDay()) ? 'weekend' : 'weekday';

    const pricingRules = await this.prisma.pricingRule.findMany({
      where: { studio_id: studioId, day_type: dayType },
    });
    const priceOf = (slotType: SlotType): number | null => {
      const rule = pricingRules.find((r) => r.slot_type === slotType);
      return rule ? Number(rule.price_per_hour) : null;
    };

    const dayStart = new Date(date);
    const dayEnd = new Date(date);
    dayEnd.setDate(dayEnd.getDate() + 1);

    // Lấy toàn bộ booking đang giữ chỗ của set này trong ngày, để loại trừ slot trùng
    const existingBookings = await this.prisma.booking.findMany({
      where: {
        set_id: targetSet.id,
        status: { in: ACTIVE_BOOKING_STATUSES },
        start_time: { lt: dayEnd },
        end_time: { gt: dayStart },
      },
      select: { start_time: true, end_time: true },
    });

    const availableSlots: { start: string; end: string; price: number | null }[] = [];

    for (let hour = OPENING_HOUR; hour < CLOSING_HOUR; hour++) {
      const slotStart = new Date(date);
      slotStart.setHours(hour, 0, 0, 0);
      const slotEnd = new Date(date);
      slotEnd.setHours(hour + 1, 0, 0, 0);

      const isOverlapping = existingBookings.some(
        (b) => b.start_time < slotEnd && b.end_time > slotStart,
      );
      if (isOverlapping) continue;

      const slotType: SlotType = hour < GOLDEN_HOUR ? 'normal' : 'golden';
      availableSlots.push({
        start: `${String(hour).padStart(2, '0')}:00`,
        end: `${String(hour + 1).padStart(2, '0')}:00`,
        price: priceOf(slotType),
      });
    }

    return {
      date: query.date,
      set_id: targetSet.id,
      available_slots: availableSlots,
    };
  }

  async findPricingRules(studioId: string) {
    await this.ensureStudioExists(studioId);
    return this.prisma.pricingRule.findMany({ where: { studio_id: studioId } });
  }

  async upsertPricingRule(studioId: string, ownerId: string, dto: UpsertPricingRuleDto) {
    await this.ensureOwnership(studioId, ownerId);

    // upsert theo unique constraint [studio_id, slot_type, day_type]:
    // đã tồn tại tổ hợp này -> cập nhật giá; chưa có -> tạo mới.
    return this.prisma.pricingRule.upsert({
      where: {
        studio_id_slot_type_day_type: {
          studio_id: studioId,
          slot_type: dto.slot_type,
          day_type: dto.day_type,
        },
      },
      create: { ...dto, studio_id: studioId },
      update: { price_per_hour: dto.price_per_hour },
    });
  }

  async deletePricingRule(studioId: string, ownerId: string, ruleId: string) {
    await this.ensureOwnership(studioId, ownerId);

    const rule = await this.prisma.pricingRule.findFirst({
      where: { id: ruleId, studio_id: studioId },
    });
    if (!rule) {
      throw new NotFoundException('Quy tắc giá không tồn tại trong studio này');
    }

    await this.prisma.pricingRule.delete({ where: { id: ruleId } });
    return { message: 'Đã xoá quy tắc giá' };
  }

  async findFeatured(limit = 10) {
    const studios = await this.prisma.studio.findMany({
      where: { status: 'active' },
      // Ưu tiên đánh giá cao nhất; nếu bằng điểm (vd: cùng 0.0 do chưa có
      // review), studio mới tạo gần đây được ưu tiên hơn để không bỏ trống
      // mục "Nổi bật" khi hệ thống còn ít dữ liệu đánh giá.
      orderBy: [{ avg_rating: 'desc' }, { created_at: 'desc' }],
      take: limit,
      select: STUDIO_SUMMARY_SELECT,
    });
    return studios.map((s) => this.toSummary(s));
  }

  async findStyleTags() {
    const sets = await this.prisma.studioSet.findMany({
      where: {
        is_active: true,
        style_tag: { not: null },
        studio: { status: 'active' },
      },
      select: { style_tag: true },
      distinct: ['style_tag'],
    });
    return sets
      .map((s) => s.style_tag)
      .filter((tag): tag is string => tag !== null);
  }

  async recordView(studioId: string, userId: string) {
    await this.ensureStudioExists(studioId);
    await this.prisma.viewHistory.create({
      data: { studio_id: studioId, user_id: userId },
    });
    return { message: 'Đã ghi nhận lượt xem' };
  }

  /**
   * Gợi ý "Dành cho bạn" — content-based đơn giản, KHÔNG phải thuật toán
   * Machine Learning phức tạp: lấy style_tag của các studio user đã xem/đặt
   * gần đây nhất, rồi gợi ý thêm studio khác cùng style_tag (ưu tiên
   * booking hơn view vì đặt lịch là tín hiệu quan tâm mạnh hơn chỉ xem).
   * Chưa có đủ lịch sử -> fallback về danh sách nổi bật (findFeatured).
   */
  async findForYou(userId: string, limit = 10) {
    const [recentBookings, recentViews] = await Promise.all([
      this.prisma.booking.findMany({
        where: { user_id: userId },
        orderBy: { created_at: 'desc' },
        take: 5,
        select: { set: { select: { style_tag: true } } },
      }),
      this.prisma.viewHistory.findMany({
        where: { user_id: userId },
        orderBy: { viewed_at: 'desc' },
        take: 10,
        select: {
          studio_id: true,
          studio: { select: { sets: { select: { style_tag: true }, take: 1 } } },
        },
      }),
    ]);

    const styleTags = new Set<string>();
    recentBookings.forEach((b) => {
      if (b.set.style_tag) styleTags.add(b.set.style_tag);
    });
    recentViews.forEach((v) => {
      v.studio.sets.forEach((s) => {
        if (s.style_tag) styleTags.add(s.style_tag);
      });
    });

    const viewedStudioIds = recentViews.map((v) => v.studio_id);

    if (styleTags.size === 0) {
      return this.findFeatured(limit);
    }

    const studios = await this.prisma.studio.findMany({
      where: {
        status: 'active',
        id: { notIn: viewedStudioIds },
        sets: { some: { style_tag: { in: Array.from(styleTags) } } },
      },
      orderBy: { avg_rating: 'desc' },
      take: limit,
      select: STUDIO_SUMMARY_SELECT,
    });

    // Lọc theo style_tag ra quá ít kết quả (thường gặp khi hệ thống còn ít
    // dữ liệu) -> bù thêm bằng danh sách nổi bật cho đủ số lượng hiển thị,
    // tránh trả về danh sách trống hoặc quá ngắn gây cảm giác app "trống".
    if (studios.length < limit) {
      const fallback = await this.findFeatured(limit);
      const existingIds = new Set(studios.map((s) => s.id));
      const extra = fallback.filter(
        (s) => !existingIds.has(s.id) && !viewedStudioIds.includes(s.id),
      );
      const combined = [...studios.map((s) => this.toSummary(s)), ...extra];

      // Đã loại trừ hết những gì user từng xem mà vẫn không còn gì để gợi ý
      // (thường gặp khi hệ thống còn ít studio) -> thà hiển thị lại danh
      // sách nổi bật (kể cả đã xem) còn hơn để trống hoàn toàn.
      if (combined.length === 0) {
        return fallback;
      }

      return combined.slice(0, limit);
    }

    return studios.map((s) => this.toSummary(s));
  }

  // ---- Helper dùng nội bộ ----

  private toSummary(s: StudioSummaryRow) {
    return {
      id: s.id,
      name: s.name,
      district: s.district,
      avg_rating: s.avg_rating,
      cover_image: s.images[0]?.url ?? null,
      // Giá thấp nhất trong bảng giá (Decimal -> number). Studio chưa khai báo
      // bảng giá -> null, phía app sẽ ẩn dòng giá.
      min_price: s.pricing_rules[0] ? Number(s.pricing_rules[0].price_per_hour) : null,
    };
  }

  /** Dùng cho controller khi chỉ cần kiểm tra quyền (vd: tải ảnh set). */
  async assertOwner(studioId: string, ownerId: string): Promise<void> {
    await this.ensureOwnership(studioId, ownerId);
  }

  private findImages(studioId: string) {
    return this.prisma.studioImage.findMany({
      where: { studio_id: studioId },
      orderBy: { sort_order: 'asc' },
    });
  }

  private async ensureImage(studioId: string, imageId: string) {
    const image = await this.prisma.studioImage.findFirst({
      where: { id: imageId, studio_id: studioId },
    });
    if (!image) throw new NotFoundException('Ảnh không tồn tại trong studio này');
    return image;
  }

  private async ensureStudioExists(studioId: string) {
    const studio = await this.prisma.studio.findUnique({ where: { id: studioId } });
    if (!studio) {
      throw new NotFoundException('Studio không tồn tại');
    }
    return studio;
  }

  private async ensureOwnership(studioId: string, userId: string) {
    const studio = await this.ensureStudioExists(studioId);
    if (studio.owner_id !== userId) {
      throw new ForbiddenException('Bạn không phải chủ sở hữu studio này');
    }
    return studio;
  }

  private async resolveTargetSet(studioId: string, setId?: string) {
    if (setId) {
      const set = await this.prisma.studioSet.findFirst({
        where: { id: setId, studio_id: studioId },
      });
      if (!set) {
        throw new NotFoundException('Bối cảnh (set) không tồn tại trong studio này');
      }
      return set;
    }

    const firstActiveSet = await this.prisma.studioSet.findFirst({
      where: { studio_id: studioId, is_active: true },
      orderBy: { created_at: 'asc' },
    });
    if (!firstActiveSet) {
      throw new BadRequestException(
        'Studio chưa có bối cảnh (set) nào đang hoạt động để kiểm tra lịch trống',
      );
    }
    return firstActiveSet;
  }
}