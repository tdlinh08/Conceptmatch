import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BookingStatus, Prisma, StaffRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStudioDto } from './dto/create-studio.dto';
import { UpdateStudioDto } from './dto/update-studio.dto';
import { QueryStudiosDto } from './dto/query-studios.dto';
import { CreateStudioSetDto } from './dto/create-studio-set.dto';
import { AvailabilityQueryDto } from './dto/availability-query.dto';
import { CreatePackageDto } from './dto/create-package.dto';
import { UpdatePackageDto } from './dto/update-package.dto';
import { STUDIO_SUMMARY_SELECT, StudioSummaryRow, toStudioSummary } from './studio-summary';
import { normalizeSearch, searchWords } from '../common/search-text';
import { distanceKm, roundKm } from '../common/geo';
import {
  addonLine,
  listStartTimes,
  PricingError,
  quotePrice,
  SLOT_STEP_MINUTES,
  toHHmm,
  toMinutes,
  withAddons,
} from '../pricing/pricing';
import { CreateStaffDto, UpdateStaffDto } from './dto/staff.dto';
import { CreateAddonDto, UpdateAddonDto } from './dto/addon.dto';
import { activeStaffCount, resolveAddons, roleBusyRanges } from './staff-rules';
import { UpdateStudioSetDto } from './dto/update-studio-set.dto';
import { AiService } from '../ai/ai.service';
import { deleteLocalMedia } from '../media/media.util';

// Khung giờ hoạt động: lấy theo từng studio (open_time / close_time), không còn cố định 8h–22h.

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
  images: { orderBy: { sort_order: 'asc' }, select: { id: true, url: true } },
} satisfies Prisma.StudioSetSelect;

/** Số ảnh tối đa trong album của 1 set. */
export const MAX_SET_IMAGES = 15;

// Gói thuê trả về cho app (giá Decimal -> number ở toPackage)
const PACKAGE_SELECT = {
  id: true,
  name: true,
  description: true,
  duration_minutes: true,
  price: true,
  included_people: true,
  extra_person_fee: true,
  max_people: true,
  is_active: true,
} satisfies Prisma.RentalPackageSelect;

type PackageRow = Prisma.RentalPackageGetPayload<{ select: typeof PACKAGE_SELECT }>;

const toPackage = (p: PackageRow) => ({
  ...p,
  price: Number(p.price),
  extra_person_fee: Number(p.extra_person_fee),
});

const STAFF_SELECT = {
  id: true,
  full_name: true,
  role: true,
  phone: true,
  avatar_url: true,
  is_active: true,
} satisfies Prisma.StaffMemberSelect;

const ADDON_SELECT = {
  id: true,
  role: true,
  name: true,
  description: true,
  price: true,
  unit: true,
  is_active: true,
} satisfies Prisma.AddonServiceSelect;

type AddonRow = Prisma.AddonServiceGetPayload<{ select: typeof ADDON_SELECT }>;
const toAddon = (a: AddonRow) => ({ ...a, price: Number(a.price) });

// Set kèm gói đang bán (dành cho khách)
const PUBLIC_SET_SELECT = {
  ...SET_SELECT,
  packages: {
    where: { is_active: true },
    orderBy: { price: 'asc' },
    select: PACKAGE_SELECT,
  },
} satisfies Prisma.StudioSetSelect;

// Set kèm MỌI gói, kể cả gói đã ẩn (dành cho chủ studio)
const OWNER_SET_SELECT = {
  ...SET_SELECT,
  packages: { orderBy: { created_at: 'asc' }, select: PACKAGE_SELECT },
} satisfies Prisma.StudioSetSelect;

type SetWithPackages = Prisma.StudioSetGetPayload<{ select: typeof PUBLIC_SET_SELECT }>;
const toSetWithPackages = (set: SetWithPackages) => ({
  ...set,
  packages: set.packages.map(toPackage),
});

@Injectable()
export class StudiosService {
  constructor(
    private prisma: PrismaService,
    private aiService: AiService,
  ) {}

  async findAll(query: QueryStudiosDto) {
    const { keyword, district, style_tag, min_price, max_price, min_rating, services, sort, page, limit } =
      query;
    const { lat, lng } = query;
    const hasPoint = lat !== undefined && lng !== undefined;
    if ((lat === undefined) !== (lng === undefined)) {
      throw new BadRequestException('Cần gửi cả lat và lng');
    }
    if (sort === 'distance' && !hasPoint) {
      throw new BadRequestException('Sắp xếp "Gần tôi" cần vị trí của bạn (lat, lng)');
    }
    // Khoảng cách tới người dùng (null nếu không gửi vị trí hoặc studio chưa ghim vị trí)
    const distanceOf = (s: { latitude: number | null; longitude: number | null }) =>
      hasPoint && s.latitude !== null && s.longitude !== null
        ? distanceKm(lat!, lng!, s.latitude, s.longitude)
        : null;
    const withDistance = (s: StudioSummaryRow) => {
      const d = distanceOf(s);
      return { ...toStudioSummary(s), distance_km: d === null ? null : roundKm(d) };
    };
    const words = searchWords(keyword ?? '');
    const roles = (services?.split(',') ?? []) as StaffRole[];

    const where: Prisma.StudioWhereInput = {
      status: 'active', // Public chỉ thấy studio đã được Admin duyệt
      // Tìm không dấu theo TỪNG TỪ trong tên / quận / địa chỉ / tên set / concept:
      // "hoa nang", "nang hoa", "Hoa Nắng" đều ra "Studio Hoa Nắng".
      ...(words.length > 0 && {
        OR: [
          { AND: words.map((w) => ({ search_text: { contains: w } })) },
          { name: { contains: keyword!.trim(), mode: 'insensitive' } }, // dự phòng
        ],
      }),
      ...(district && { district }),
      ...(min_rating !== undefined && { avg_rating: { gte: min_rating } }),
      AND: [
        ...(style_tag ? [{ sets: { some: { style_tag, is_active: true } } }] : []),
        // Dịch vụ kèm theo: đang bán dịch vụ của vai trò đó và có người đang làm
        ...roles.map((role) => ({
          addons: { some: { role, is_active: true } },
          staff: { some: { role, is_active: true } },
        })),
        // Lọc theo giá: có ít nhất 1 gói đang bán nằm trong khoảng giá
        ...(min_price !== undefined || max_price !== undefined
          ? [
              {
                sets: {
                  some: {
                    is_active: true,
                    packages: {
                      some: {
                        is_active: true,
                        price: {
                          ...(min_price !== undefined && { gte: min_price }),
                          ...(max_price !== undefined && { lte: max_price }),
                        },
                      },
                    },
                  },
                },
              },
            ]
          : []),
      ],
    };

    if (sort === 'distance') {
      // Prisma không sắp theo biểu thức tính toán -> lấy toạ độ mọi studio khớp bộ lọc,
      // tính khoảng cách, sắp xếp, cắt trang rồi mới lấy dữ liệu thẻ của trang đó.
      // Phù hợp quy mô đồ án (vài chục studio); quy mô lớn nên dùng PostGIS / earthdistance.
      const points = await this.prisma.studio.findMany({
        where,
        select: { id: true, latitude: true, longitude: true },
      });
      const ranked = points
        .map((p) => ({ id: p.id, d: distanceOf(p) ?? Number.POSITIVE_INFINITY })) // chưa ghim -> cuối
        .sort((a, b) => a.d - b.d);
      const pageIds = ranked.slice((page - 1) * limit, page * limit).map((r) => r.id);
      const rows = await this.prisma.studio.findMany({
        where: { id: { in: pageIds } },
        select: STUDIO_SUMMARY_SELECT,
      });
      const byId = new Map(rows.map((r) => [r.id, r]));
      return {
        data: pageIds.map((id) => byId.get(id)!).filter(Boolean).map(withDistance),
        total: ranked.length,
        page,
        limit,
      };
    }

    const [data, total] = await this.prisma.$transaction([
      this.prisma.studio.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy:
          sort === 'newest'
            ? [{ created_at: 'desc' }]
            : [{ avg_rating: 'desc' }, { review_count: 'desc' }, { created_at: 'desc' }],
        select: STUDIO_SUMMARY_SELECT,
      }),
      this.prisma.studio.count({ where }),
    ]);

    return {
      data: data.map(withDistance),
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
        sets: { where: { is_active: true }, orderBy: { created_at: 'asc' }, select: PUBLIC_SET_SELECT },
      },
    });

    if (!studio) {
      throw new NotFoundException('Studio không tồn tại');
    }

    // Số thợ đang làm theo vai trò; dịch vụ của vai trò chưa có ai thì ẩn với khách
    const counts = await this.prisma.staffMember.groupBy({
      by: ['role'],
      where: { studio_id: id, is_active: true },
      _count: { _all: true },
    });
    const staff_counts = { photographer: 0, makeup: 0 };
    counts.forEach((c) => (staff_counts[c.role] = c._count._all));
    const addons = await this.prisma.addonService.findMany({
      where: { studio_id: id, is_active: true },
      orderBy: [{ role: 'asc' }, { price: 'asc' }],
      select: ADDON_SELECT,
    });

    return {
      ...studio,
      sets: studio.sets.map(toSetWithPackages),
      staff_counts,
      addons: addons.filter((a) => staff_counts[a.role] > 0).map(toAddon),
    };
  }

  async create(ownerId: string, dto: CreateStudioDto) {
    this.assertOpeningHours(dto.open_time ?? '08:00', dto.close_time ?? '22:00');
    this.assertLocation(dto);
    return this.prisma.studio.create({
      data: {
        ...dto,
        owner_id: ownerId,
        status: 'pending', // Luôn tạo ở trạng thái chờ duyệt, Admin phê duyệt sau
        search_text: normalizeSearch([dto.name, dto.district, dto.address].join(' ')),
      },
    });
  }

  async update(id: string, ownerId: string, dto: UpdateStudioDto) {
    const studio = await this.ensureOwnership(id, ownerId);
    this.assertOpeningHours(dto.open_time ?? studio.open_time, dto.close_time ?? studio.close_time);
    this.assertLocation(dto);

    await this.prisma.studio.update({
      where: { id },
      data: {
        ...dto,
        // Bị từ chối -> chủ studio sửa lại thông tin -> tự động gửi duyệt lại
        ...(studio.status === 'rejected' && { status: 'pending', reject_reason: null }),
      },
    });
    return this.refreshSearchText(id); // tên / quận / địa chỉ có thể đã đổi
  }

  /** Tính lại chữ tìm kiếm (bỏ dấu) từ tên, quận, địa chỉ, tên set + concept đang hoạt động. */
  private async refreshSearchText(studioId: string) {
    const s = await this.prisma.studio.findUniqueOrThrow({
      where: { id: studioId },
      select: {
        name: true,
        district: true,
        address: true,
        sets: { where: { is_active: true }, select: { name: true, style_tag: true } },
      },
    });
    const text = normalizeSearch(
      [s.name, s.district, s.address, ...s.sets.flatMap((x) => [x.name, x.style_tag ?? ''])].join(' '),
    );
    return this.prisma.studio.update({ where: { id: studioId }, data: { search_text: text } });
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
      ...toStudioSummary(s),
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
    return this.findFull(id);
  }

  /** Toàn bộ thông tin 1 studio (mọi trạng thái, gồm cả mục đang ẩn) — chủ studio và admin dùng. */
  async findFull(id: string) {
    const studio = await this.prisma.studio.findUnique({
      where: { id },
      include: {
        images: { orderBy: { sort_order: 'asc' } },
        sets: { orderBy: { created_at: 'asc' }, select: OWNER_SET_SELECT },
        staff: { orderBy: [{ role: 'asc' }, { full_name: 'asc' }], select: STAFF_SELECT },
        addons: { orderBy: [{ role: 'asc' }, { created_at: 'asc' }], select: ADDON_SELECT },
        owner: { select: { id: true, full_name: true, email: true, status: true } },
      },
    });
    if (!studio) throw new NotFoundException('Studio không tồn tại');
    return {
      ...studio,
      sets: studio.sets.map(toSetWithPackages),
      addons: studio.addons.map(toAddon),
    };
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

  // ---- Album ảnh của set ----

  /** Thêm ảnh vào album set (tối đa MAX_SET_IMAGES ảnh / set). Trả về album mới. */
  async addSetImages(studioId: string, setId: string, ownerId: string, urls: string[]) {
    const studio = await this.ensureOwnership(studioId, ownerId);
    await this.ensureSet(studioId, setId);
    if (urls.length === 0) throw new BadRequestException('Chưa chọn ảnh nào');

    const [count, last] = await Promise.all([
      this.prisma.setImage.count({ where: { set_id: setId } }),
      this.prisma.setImage.findFirst({
        where: { set_id: setId },
        orderBy: { sort_order: 'desc' },
        select: { sort_order: true },
      }),
    ]);
    if (count + urls.length > MAX_SET_IMAGES) {
      throw new BadRequestException(
        `Mỗi bối cảnh tối đa ${MAX_SET_IMAGES} ảnh (đang có ${count}, còn thêm được ${Math.max(0, MAX_SET_IMAGES - count)})`,
      );
    }
    const start = (last?.sort_order ?? -1) + 1;
    await this.prisma.setImage.createMany({
      data: urls.map((url, i) => ({ set_id: setId, url, sort_order: start + i })),
    });
    // Studio đang hoạt động: tạo vector cho ảnh mới để AI tìm được theo cả ảnh album
    if (studio.status === 'active') await this.aiService.indexSets([setId]);
    return this.findSetImages(setId);
  }

  async deleteSetImage(studioId: string, setId: string, ownerId: string, imageId: string) {
    const studio = await this.ensureOwnership(studioId, ownerId);
    await this.ensureSet(studioId, setId);
    const image = await this.prisma.setImage.findFirst({ where: { id: imageId, set_id: setId } });
    if (!image) throw new NotFoundException('Ảnh không tồn tại trong bối cảnh này');

    await this.prisma.setImage.delete({ where: { id: imageId } });
    await deleteLocalMedia(image.url);
    if (studio.status === 'active') await this.aiService.reindex(); // bỏ vector của ảnh đã xoá
    return this.findSetImages(setId);
  }

  private findSetImages(setId: string) {
    return this.prisma.setImage.findMany({
      where: { set_id: setId },
      orderBy: { sort_order: 'asc' },
      select: { id: true, url: true },
    });
  }

  /** Sửa set. Đổi ảnh đại diện / ẩn-hiện set khi studio đang hoạt động -> cập nhật AI index. */
  async updateSet(studioId: string, setId: string, ownerId: string, dto: UpdateStudioSetDto) {
    const studio = await this.ensureOwnership(studioId, ownerId);
    const set = await this.prisma.studioSet.findFirst({
      where: { id: setId, studio_id: studioId },
      select: SET_SELECT,
    });
    if (!set) throw new NotFoundException('Bối cảnh (set) không tồn tại trong studio này');

    // Giảm sức chứa: không được nhỏ hơn "số người tối đa" của gói đang bán trong set
    if (dto.capacity !== undefined && dto.capacity < set.capacity) {
      const biggest = await this.prisma.rentalPackage.aggregate({
        where: { set_id: setId, is_active: true },
        _max: { max_people: true },
      });
      const maxPeople = biggest._max.max_people ?? 0;
      if (dto.capacity < maxPeople) {
        throw new BadRequestException(
          `Có gói thuê cho tối đa ${maxPeople} người — giảm số người tối đa của gói trước khi giảm sức chứa xuống ${dto.capacity}`,
        );
      }
    }

    const avatarChanged = dto.avatar_url !== undefined && dto.avatar_url !== set.avatar_url;
    const activeChanged = dto.is_active !== undefined && dto.is_active !== set.is_active;

    const updated = await this.prisma.studioSet.update({
      where: { id: setId },
      data: dto,
      select: SET_SELECT,
    });
    await this.refreshSearchText(studioId); // đổi tên / concept / ẩn-hiện set

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

    const sets = await this.prisma.studioSet.findMany({
      where: { studio_id: studioId, is_active: true },
      orderBy: { created_at: 'asc' },
      select: PUBLIC_SET_SELECT,
    });
    return sets.map(toSetWithPackages);
  }

  async createSet(studioId: string, ownerId: string, dto: CreateStudioSetDto) {
    const studio = await this.ensureOwnership(studioId, ownerId);

    const set = await this.prisma.studioSet.create({
      data: { ...dto, studio_id: studioId },
      select: SET_SELECT,
    });
    await this.refreshSearchText(studioId); // tên set + concept mới tìm được ngay

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
        where: { studio_id: studioId, is_hidden: false }, // đánh giá bị admin ẩn không hiện công khai
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
      this.prisma.review.count({ where: { studio_id: studioId, is_hidden: false } }),
    ]);

    return { data, total };
  }

  /**
   * Giờ bắt đầu còn trống trong 1 ngày cho 1 GÓI cụ thể (gói -> set -> lịch riêng của set).
   * Mỗi giờ bắt đầu kèm giá đã tính đủ số người + phụ thu giờ tối / cuối tuần,
   * dùng đúng công thức với POST /bookings (src/pricing/pricing.ts).
   */
  async getAvailability(studioId: string, query: AvailabilityQueryDto) {
    const pkg = await this.prisma.rentalPackage.findFirst({
      where: {
        id: query.package_id,
        is_active: true,
        set: { is_active: true, studio_id: studioId },
      },
      include: { set: { include: { studio: true } } },
    });
    if (!pkg) {
      throw new NotFoundException('Gói thuê không tồn tại trong studio này');
    }
    const studio = pkg.set.studio;

    const date = new Date(`${query.date}T00:00:00`);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException('date không hợp lệ');
    }
    const dayEnd = new Date(date);
    dayEnd.setDate(dayEnd.getDate() + 1);
    const numPeople = query.num_people ?? Math.min(pkg.included_people, pkg.max_people);
    const addons = await resolveAddons(this.prisma, studioId, query.addon_ids?.split(','));

    // Mỗi vai trò khách chọn: số người đang làm + các đơn trong ngày đang dùng vai trò đó
    const roles = await Promise.all(
      addons.map(async (a) => ({
        role: a.role,
        capacity: await activeStaffCount(this.prisma, studioId, a.role),
        busy: await roleBusyRanges(this.prisma, studioId, a.role, date, dayEnd),
      })),
    );
    const noStaff = roles.find((r) => r.capacity === 0);
    if (noStaff) {
      throw new BadRequestException('Studio hiện chưa có người cho dịch vụ đã chọn');
    }

    // Booking đang giữ chỗ của SET này trong ngày (mọi gói của set dùng chung một lịch)
    const busy = await this.prisma.booking.findMany({
      where: {
        set_id: pkg.set_id,
        status: { in: ACTIVE_BOOKING_STATUSES },
        start_time: { lt: dayEnd },
        end_time: { gt: date },
      },
      select: { start_time: true, end_time: true },
    });

    try {
      const starts = listStartTimes({
        date,
        openTime: studio.open_time,
        closeTime: studio.close_time,
        durationMinutes: pkg.duration_minutes,
        busy: busy.map((b) => ({ start: b.start_time, end: b.end_time })),
        roles,
      });

      // Tiền dịch vụ không phụ thuộc giờ bắt đầu -> tính 1 lần
      const addonsAmount = addons.reduce(
        (sum, a) =>
          sum + addonLine({ price: Number(a.price), unit: a.unit }, pkg.duration_minutes, numPeople).amount,
        0,
      );

      const pricing = { ...toPackage(pkg) };
      const hhmm = (d: Date) => toHHmm(d.getHours() * 60 + d.getMinutes());

      return {
        date: query.date,
        set_id: pkg.set_id,
        package_id: pkg.id,
        duration_minutes: pkg.duration_minutes,
        num_people: numPeople,
        addon_ids: addons.map((a) => a.id),
        addons_amount: addonsAmount,
        open_time: studio.open_time,
        close_time: studio.close_time,
        step_minutes: SLOT_STEP_MINUTES,
        available_slots: starts.map(({ start, end }) => {
          const q = withAddons(quotePrice(pricing, studio, numPeople, start), addonsAmount);
          return {
            start: hhmm(start),
            end: hhmm(end),
            price: q.total_amount, // đã gồm người thêm + phụ thu + dịch vụ thêm
            surcharge_pct: q.surcharge_pct,
          };
        }),
      };
    } catch (err) {
      if (err instanceof PricingError) throw new BadRequestException(err.message);
      throw err;
    }
  }

  // ===========================================================================
  // Gói thuê (thay cho bảng giá 4 ô cũ)
  // ===========================================================================

  async createPackage(studioId: string, setId: string, ownerId: string, dto: CreatePackageDto) {
    const studio = await this.ensureOwnership(studioId, ownerId);
    const set = await this.ensureSet(studioId, setId);
    this.assertPackage(dto, set.capacity, studio);

    const pkg = await this.prisma.rentalPackage.create({
      data: { ...dto, extra_person_fee: dto.extra_person_fee ?? 0, set_id: setId },
      select: PACKAGE_SELECT,
    });
    return toPackage(pkg);
  }

  async updatePackage(
    studioId: string,
    setId: string,
    packageId: string,
    ownerId: string,
    dto: UpdatePackageDto,
  ) {
    const studio = await this.ensureOwnership(studioId, ownerId);
    const set = await this.ensureSet(studioId, setId);
    const current = await this.prisma.rentalPackage.findFirst({
      where: { id: packageId, set_id: setId },
      select: PACKAGE_SELECT,
    });
    if (!current) throw new NotFoundException('Gói thuê không tồn tại trong set này');

    // Kiểm tra trên giá trị SAU khi sửa (vd chỉ gửi max_people vẫn phải >= included_people cũ)
    const merged = { ...toPackage(current), ...dto };
    this.assertPackage(merged, set.capacity, studio);

    const pkg = await this.prisma.rentalPackage.update({
      where: { id: packageId },
      data: dto,
      select: PACKAGE_SELECT,
    });
    return toPackage(pkg);
  }

  // ===========================================================================
  // Nhân sự (thợ ảnh / trang điểm) + dịch vụ thêm
  // ===========================================================================

  async findStaff(studioId: string, ownerId: string) {
    await this.ensureOwnership(studioId, ownerId);
    return this.prisma.staffMember.findMany({
      where: { studio_id: studioId },
      orderBy: [{ role: 'asc' }, { full_name: 'asc' }],
      select: STAFF_SELECT,
    });
  }

  async createStaff(studioId: string, ownerId: string, dto: CreateStaffDto) {
    await this.ensureOwnership(studioId, ownerId);
    return this.prisma.staffMember.create({
      data: { ...dto, studio_id: studioId },
      select: STAFF_SELECT,
    });
  }

  async updateStaff(studioId: string, staffId: string, ownerId: string, dto: UpdateStaffDto) {
    await this.ensureOwnership(studioId, ownerId);
    const staff = await this.prisma.staffMember.findFirst({
      where: { id: staffId, studio_id: studioId },
    });
    if (!staff) throw new NotFoundException('Nhân sự không tồn tại trong studio này');
    if (dto.role && dto.role !== staff.role) {
      // Đổi vai trò làm lệch các phân công đang có -> bắt tạo nhân sự mới
      const assigned = await this.prisma.bookingAddon.count({ where: { staff_id: staffId } });
      if (assigned > 0) {
        throw new BadRequestException('Nhân sự đã được phân công đơn, không đổi vai trò được');
      }
    }
    return this.prisma.staffMember.update({
      where: { id: staffId },
      data: dto,
      select: STAFF_SELECT,
    });
  }

  async createAddon(studioId: string, ownerId: string, dto: CreateAddonDto) {
    await this.ensureOwnership(studioId, ownerId);
    const addon = await this.prisma.addonService.create({
      data: { ...dto, studio_id: studioId },
      select: ADDON_SELECT,
    });
    return toAddon(addon);
  }

  async updateAddon(studioId: string, addonId: string, ownerId: string, dto: UpdateAddonDto) {
    await this.ensureOwnership(studioId, ownerId);
    const exists = await this.prisma.addonService.count({
      where: { id: addonId, studio_id: studioId },
    });
    if (!exists) throw new NotFoundException('Dịch vụ không tồn tại trong studio này');
    // Đơn đã đặt giữ tên + giá cũ (snapshot ở booking_addons) nên sửa thoải mái
    const addon = await this.prisma.addonService.update({
      where: { id: addonId },
      data: dto,
      select: ADDON_SELECT,
    });
    return toAddon(addon);
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
    return studios.map((s) => toStudioSummary(s));
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
      const combined = [...studios.map((s) => toStudioSummary(s)), ...extra];

      // Đã loại trừ hết những gì user từng xem mà vẫn không còn gì để gợi ý
      // (thường gặp khi hệ thống còn ít studio) -> thà hiển thị lại danh
      // sách nổi bật (kể cả đã xem) còn hơn để trống hoàn toàn.
      if (combined.length === 0) {
        return fallback;
      }

      return combined.slice(0, limit);
    }

    return studios.map((s) => toStudioSummary(s));
  }

  // ---- Helper dùng nội bộ ----

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

  private async ensureSet(studioId: string, setId: string) {
    const set = await this.prisma.studioSet.findFirst({
      where: { id: setId, studio_id: studioId },
      select: { id: true, capacity: true },
    });
    if (!set) throw new NotFoundException('Bối cảnh (set) không tồn tại trong studio này');
    return set;
  }

  /** Giờ mở cửa hợp lệ: đóng sau mở ít nhất 1 tiếng, không vắt qua nửa đêm. */
  /** Toạ độ phải đi theo cặp: cùng có số, cùng null (xoá ghim) hoặc cùng không gửi. */
  private assertLocation(dto: { latitude?: number | null; longitude?: number | null }) {
    const kind = (v: number | null | undefined) =>
      v === undefined ? 'missing' : v === null ? 'null' : 'number';
    if (kind(dto.latitude) !== kind(dto.longitude)) {
      throw new BadRequestException('Vị trí cần đủ cả latitude và longitude');
    }
  }

  private assertOpeningHours(openTime: string, closeTime: string) {
    try {
      if (toMinutes(closeTime) - toMinutes(openTime) < 60) {
        throw new BadRequestException(
          'Giờ đóng cửa phải sau giờ mở cửa ít nhất 1 tiếng (không hỗ trợ mở qua nửa đêm; mở 24/7 thì nhập 00:00 – 24:00)',
        );
      }
    } catch (err) {
      if (err instanceof PricingError) throw new BadRequestException(err.message);
      throw err;
    }
  }

  /** Ràng buộc chéo giữa các trường của gói — class-validator không kiểm được. */
  private assertPackage(
    pkg: { duration_minutes: number; included_people: number; max_people: number },
    setCapacity: number,
    studio: { open_time: string; close_time: string },
  ) {
    if (pkg.duration_minutes % SLOT_STEP_MINUTES !== 0) {
      throw new BadRequestException(`Thời lượng gói phải là bội số của ${SLOT_STEP_MINUTES} phút`);
    }
    const window = toMinutes(studio.close_time) - toMinutes(studio.open_time);
    if (pkg.duration_minutes > window) {
      throw new BadRequestException(
        `Gói dài ${pkg.duration_minutes} phút vượt giờ mở cửa của studio (${studio.open_time}–${studio.close_time})`,
      );
    }
    if (pkg.max_people < pkg.included_people) {
      throw new BadRequestException('Số người tối đa phải >= số người đã gồm trong giá');
    }
    if (pkg.max_people > setCapacity) {
      throw new BadRequestException(
        `Số người tối đa (${pkg.max_people}) vượt sức chứa của set (${setCapacity}) — sửa sức chứa set trước`,
      );
    }
  }
}
