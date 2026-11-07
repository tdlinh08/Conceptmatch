import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AiService } from '../ai/ai.service';
import { QueryUsersDto } from './dto/query-users.dto';
import { RejectStudioDto } from './dto/reject-studio.dto';
import { LockUserDto } from './dto/lock-user.dto';
import { QueryAdminStudiosDto } from './dto/query-admin-studios.dto';
import { QueryAuditLogsDto } from './dto/query-audit-logs.dto';
import { StudiosService } from '../studios/studios.service';
import { normalizeSearch, searchWords } from '../common/search-text';
import { Prisma } from '@prisma/client';

function startOfToday(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}
function startOfTomorrow(): Date {
  const d = startOfToday();
  d.setDate(d.getDate() + 1);
  return d;
}
function startOfMonth(): Date {
  const d = new Date();
  d.setDate(1);
  d.setHours(0, 0, 0, 0);
  return d;
}

@Injectable()
export class AdminService {
  constructor(
    private prisma: PrismaService,
    private aiService: AiService,
    private studiosService: StudiosService,
  ) {}

  /** Danh sách studio mọi trạng thái (trang admin): lọc trạng thái + từ khoá. */
  async findStudios(query: QueryAdminStudiosDto) {
    const { status, keyword, page, limit } = query;
    const words = keyword ? searchWords(normalizeSearch(keyword)) : [];
    const where: Prisma.StudioWhereInput = {
      ...(status && { status }),
      ...(keyword?.trim() && {
        OR: [
          // tên / quận / địa chỉ: tìm không dấu qua search_text
          ...(words.length ? [{ AND: words.map((w) => ({ search_text: { contains: w } })) }] : []),
          { owner: { full_name: { contains: keyword.trim(), mode: 'insensitive' as const } } },
          { owner: { email: { contains: keyword.trim(), mode: 'insensitive' as const } } },
        ],
      }),
    };
    const [rows, total, counts] = await this.prisma.$transaction([
      this.prisma.studio.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        // chờ duyệt: cũ nhất lên đầu (xử lý theo thứ tự gửi); còn lại: mới nhất lên đầu
        orderBy: { created_at: status === 'pending' ? 'asc' : 'desc' },
        select: {
          id: true,
          name: true,
          district: true,
          address: true,
          status: true,
          reject_reason: true,
          avg_rating: true,
          created_at: true,
          owner: { select: { id: true, full_name: true, email: true } },
          images: { where: { is_cover: true }, take: 1, select: { url: true } },
          _count: { select: { sets: true, images: true, bookings: true } },
        },
      }),
      this.prisma.studio.count({ where }),
      this.prisma.studio.groupBy({ by: ['status'], _count: { _all: true }, orderBy: { status: 'asc' } }),
    ]);
    const byStatus = { pending: 0, active: 0, rejected: 0 };
    for (const c of counts) byStatus[c.status] = (c._count as { _all: number })._all;
    return {
      data: rows.map((s) => ({
        id: s.id,
        name: s.name,
        district: s.district,
        address: s.address,
        status: s.status,
        reject_reason: s.reject_reason,
        avg_rating: Number(s.avg_rating),
        created_at: s.created_at,
        owner: s.owner,
        cover_image: s.images[0]?.url ?? null,
        set_count: s._count.sets,
        image_count: s._count.images,
        booking_count: s._count.bookings,
      })),
      total,
      page,
      limit,
      counts: byStatus, // số studio theo trạng thái (cho nhãn tab)
    };
  }

  /** Chi tiết 1 studio để admin xem trước khi duyệt (mọi trạng thái, kèm chủ studio). */
  findStudio(id: string) {
    return this.studiosService.findFull(id);
  }

  /**
   * GỠ studio đang hoạt động (vi phạm, thông tin sai...): chuyển sang "rejected" kèm lý do,
   * khách không thấy nữa; chủ studio sửa lại sẽ tự gửi duyệt lại. Đơn đã đặt giữ nguyên.
   */
  async takeDownStudio(studioId: string, adminId: string, dto: RejectStudioDto) {
    const studio = await this.prisma.studio.findUnique({ where: { id: studioId } });
    if (!studio) throw new NotFoundException('Studio không tồn tại');
    if (studio.status !== 'active') {
      throw new ConflictException('Chỉ gỡ được studio đang hoạt động');
    }
    await this.prisma.studio.update({
      where: { id: studioId },
      data: { status: 'rejected', reject_reason: dto.reason },
    });
    await this.prisma.auditLog.create({
      data: {
        admin_id: adminId,
        action: 'Gỡ studio',
        target_type: 'studio',
        target_id: studioId,
        note: dto.reason,
      },
    });
    await this.prisma.notification.create({
      data: {
        recipient_id: studio.owner_id,
        type: 'studio_rejected',
        title: 'Studio đã bị gỡ khỏi sàn',
        body: `${dto.reason} — sửa lại thông tin để gửi duyệt lại.`,
        ref_id: studioId,
      },
    });
    // Bỏ các set của studio này khỏi chỉ mục tìm kiếm bằng ảnh
    const aiWarning = await this.aiService.reindex();
    return {
      id: studioId,
      status: 'rejected',
      ...(aiWarning && { warnings: [aiWarning] }),
    };
  }

  /** Nhật ký thao tác của admin (duyệt / từ chối / gỡ studio, khoá / mở khoá tài khoản). */
  async findAuditLogs(query: QueryAuditLogsDto) {
    const { target_type, page, limit } = query;
    const where = target_type ? { target_type } : {};
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.auditLog.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' },
        include: { admin: { select: { full_name: true } } },
      }),
      this.prisma.auditLog.count({ where }),
    ]);
    // Gắn tên đối tượng (studio / người dùng) để đọc được ngay
    const studioIds = rows.filter((r) => r.target_type === 'studio').map((r) => r.target_id);
    const userIds = rows.filter((r) => r.target_type === 'user').map((r) => r.target_id);
    const [studios, users] = await Promise.all([
      this.prisma.studio.findMany({ where: { id: { in: studioIds } }, select: { id: true, name: true } }),
      this.prisma.user.findMany({ where: { id: { in: userIds } }, select: { id: true, full_name: true } }),
    ]);
    const names = new Map<string, string>([
      ...studios.map((s) => [s.id, s.name] as [string, string]),
      ...users.map((u) => [u.id, u.full_name] as [string, string]),
    ]);
    return {
      data: rows.map((r) => ({
        id: r.id,
        action: r.action,
        target_type: r.target_type,
        target_id: r.target_id,
        target_name: names.get(r.target_id) ?? null,
        note: r.note,
        admin_name: r.admin.full_name,
        created_at: r.created_at,
      })),
      total,
      page,
      limit,
    };
  }

  async findPendingStudios(page = 1, limit = 10) {
    const where = { status: 'pending' as const };
    const [data, total] = await this.prisma.$transaction([
      this.prisma.studio.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'asc' },
        include: { owner: { select: { full_name: true } } },
      }),
      this.prisma.studio.count({ where }),
    ]);

    return {
      data: data.map((s) => ({
        id: s.id,
        name: s.name,
        district: s.district,
        owner_name: s.owner.full_name,
        created_at: s.created_at,
      })),
      total,
    };
  }

  async approveStudio(studioId: string, adminId: string) {
    const studio = await this.prisma.studio.findUnique({ where: { id: studioId } });
    if (!studio) {
      throw new NotFoundException('Studio không tồn tại');
    }
    if (studio.status !== 'pending') {
      throw new ConflictException('Studio đã được duyệt trước đó');
    }

    // Studio phải bán được ít nhất 1 gói, nếu không khách vào xem mà không đặt được lịch
    const bookableSets = await this.prisma.studioSet.count({
      where: { studio_id: studioId, is_active: true, packages: { some: { is_active: true } } },
    });
    if (bookableSets === 0) {
      throw new BadRequestException(
        'Studio chưa có set nào có gói thuê đang bán — chưa thể duyệt',
      );
    }

    await this.prisma.studio.update({
      where: { id: studioId },
      data: { status: 'active', reject_reason: null },
    });

    await this.prisma.auditLog.create({
      data: {
        admin_id: adminId,
        action: 'Phê duyệt studio',
        target_type: 'studio',
        target_id: studioId,
      },
    });

    await this.prisma.notification.create({
      data: {
        recipient_id: studio.owner_id,
        type: 'studio_approved',
        title: 'Studio đã được phê duyệt',
        body: `Studio "${studio.name}" đã được phê duyệt và hiển thị trên sàn.`,
        ref_id: studioId,
      },
    });

    // Sau khi duyệt: tự động mã hoá ảnh của từng Studio Set thành CLIP embedding
    // và nạp vào FAISS index — đúng theo luồng UC-04 trong SRS.
    const warnings = await this.aiService.indexStudio(studioId);

    return {
      id: studioId,
      status: 'active',
      message: 'Studio đã được phê duyệt',
      ...(warnings.length > 0 && { warnings }),
    };
  }

  async rejectStudio(studioId: string, adminId: string, dto: RejectStudioDto) {
    const studio = await this.prisma.studio.findUnique({ where: { id: studioId } });
    if (!studio) {
      throw new NotFoundException('Studio không tồn tại');
    }
    if (studio.status !== 'pending') {
      throw new ConflictException('Studio không ở trạng thái chờ duyệt');
    }

    const updated = await this.prisma.studio.update({
      where: { id: studioId },
      data: { status: 'rejected', reject_reason: dto.reason },
    });

    await this.prisma.auditLog.create({
      data: {
        admin_id: adminId,
        action: 'Từ chối studio',
        target_type: 'studio',
        target_id: studioId,
        note: dto.reason,
      },
    });

    await this.prisma.notification.create({
      data: {
        recipient_id: studio.owner_id,
        type: 'studio_rejected',
        title: 'Studio bị từ chối',
        body: dto.reason,
        ref_id: studioId,
      },
    });

    return { id: updated.id, status: updated.status };
  }

  async findUsers(query: QueryUsersDto) {
    const { keyword, role, status, page, limit } = query;
    const where = {
      ...(keyword && {
        OR: [
          { full_name: { contains: keyword, mode: 'insensitive' as const } },
          { email: { contains: keyword, mode: 'insensitive' as const } },
        ],
      }),
      ...(role && { role }),
      ...(status && { status }),
    };

    const [data, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' },
        select: {
          id: true,
          full_name: true,
          email: true,
          role: true,
          status: true,
          created_at: true,
        },
      }),
      this.prisma.user.count({ where }),
    ]);

    return { data, total };
  }

  async lockUser(userId: string, adminId: string, dto: LockUserDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Tài khoản không tồn tại');
    }
    if (user.role === 'admin') {
      throw new ForbiddenException('Không thể khoá tài khoản Admin khác');
    }

    if (user.status === 'locked') {
      throw new ConflictException('Tài khoản đã bị khoá trước đó');
    }

    // Khoá + xoá refresh token -> không làm mới phiên được nữa (access token cũ tự hết hạn sau 15 phút)
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { status: 'locked', refresh_token_hash: null },
    });

    await this.prisma.auditLog.create({
      data: {
        admin_id: adminId,
        action: 'Khóa người dùng',
        target_type: 'user',
        target_id: userId,
        note: dto.reason,
      },
    });

    return { id: updated.id, status: updated.status };
  }

  // Bổ sung so với API Contract gốc (chỉ có "lock", SRS có nhắc "mở khoá" nhưng
  // API Contract 27 endpoint không có endpoint này).
  async unlockUser(userId: string, adminId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User không tồn tại');
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { status: 'active' },
    });

    await this.prisma.auditLog.create({
      data: {
        admin_id: adminId,
        action: 'Mở khóa người dùng',
        target_type: 'user',
        target_id: userId,
      },
    });

    return { id: updated.id, status: updated.status };
  }

  async getDashboard() {
    const [
      totalStudios,
      pendingStudios,
      totalUsers,
      totalBookingsToday,
      revenueAgg,
      topStudiosRaw,
    ] = await Promise.all([
      this.prisma.studio.count({ where: { status: 'active' } }),
      this.prisma.studio.count({ where: { status: 'pending' } }),
      this.prisma.user.count(),
      this.prisma.booking.count({
        where: { created_at: { gte: startOfToday(), lt: startOfTomorrow() } },
      }),
      this.prisma.booking.aggregate({
        where: { status: 'completed', created_at: { gte: startOfMonth() } },
        _sum: { total_amount: true },
      }),
      this.prisma.booking.groupBy({
        by: ['studio_id'],
        _count: { id: true },
        orderBy: { _count: { id: 'desc' } },
        take: 5,
      }),
    ]);

    const studioIds = topStudiosRaw.map((t) => t.studio_id);
    const studios = await this.prisma.studio.findMany({
      where: { id: { in: studioIds } },
      select: { id: true, name: true, avg_rating: true },
    });
    const studioMap = new Map(studios.map((s) => [s.id, s]));

    const top_studios = topStudiosRaw.map((t) => ({
      name: studioMap.get(t.studio_id)?.name ?? 'N/A',
      booking_count: t._count.id,
      avg_rating: studioMap.get(t.studio_id)?.avg_rating ?? 0,
    }));

    // Bổ sung cho trang tổng quan: người dùng theo vai trò, đơn tháng này theo trạng thái
    const [usersByRole, bookingsByStatus, newUsersThisMonth] = await Promise.all([
      this.prisma.user.groupBy({ by: ['role'], _count: { _all: true } }),
      this.prisma.booking.groupBy({
        by: ['status'],
        where: { created_at: { gte: startOfMonth() } },
        _count: { _all: true },
      }),
      this.prisma.user.count({ where: { created_at: { gte: startOfMonth() } } }),
    ]);

    return {
      total_studios: totalStudios,
      pending_studios: pendingStudios,
      total_users: totalUsers,
      total_bookings_today: totalBookingsToday,
      revenue_this_month: Number(revenueAgg._sum.total_amount ?? 0),
      top_studios: top_studios.map((t) => ({ ...t, avg_rating: Number(t.avg_rating) })),
      new_users_this_month: newUsersThisMonth,
      users_by_role: Object.fromEntries(usersByRole.map((u) => [u.role, u._count._all])),
      bookings_this_month: Object.fromEntries(bookingsByStatus.map((b) => [b.status, b._count._all])),
    };
  }
}
