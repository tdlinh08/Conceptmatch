import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import FormData from 'form-data';
import { PrismaService } from '../prisma/prisma.service';
import { QueryUsersDto } from './dto/query-users.dto';
import { RejectStudioDto } from './dto/reject-studio.dto';
import { LockUserDto } from './dto/lock-user.dto';

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
    private http: HttpService,
    private config: ConfigService,
  ) {}

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
    const warnings = await this.encodeAndIndexSets(studioId);

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
      throw new NotFoundException('User không tồn tại');
    }
    if (user.role === 'admin') {
      throw new ForbiddenException('Không thể khoá tài khoản Admin khác');
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { status: 'locked' },
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

    return {
      total_studios: totalStudios,
      pending_studios: pendingStudios,
      total_users: totalUsers,
      total_bookings_today: totalBookingsToday,
      revenue_this_month: Number(revenueAgg._sum.total_amount ?? 0),
      top_studios,
    };
  }

  // ---- Helper: tự động encode ảnh + nạp FAISS index ----

  private async encodeAndIndexSets(studioId: string): Promise<string[]> {
    const warnings: string[] = [];
    const sets = await this.prisma.studioSet.findMany({
      where: { studio_id: studioId, is_active: true },
    });

    const aiServiceUrl =
      this.config.get<string>('AI_SERVICE_URL') ?? 'http://localhost:8000';

    for (const set of sets) {
      try {
        // Tải ảnh từ avatar_url (URL do Owner cung cấp) về dạng bytes
        const imageResponse = await firstValueFrom(
          this.http.get(set.avatar_url, {
            responseType: 'arraybuffer',
            timeout: 10000,
          }),
        );
        const imageBuffer = Buffer.from(imageResponse.data);

        const form = new FormData();
        form.append('image', imageBuffer, { filename: 'avatar.jpg' });

        const encodeResponse = await firstValueFrom(
          this.http.post(`${aiServiceUrl}/encode`, form, {
            headers: form.getHeaders(),
            timeout: 15000,
          }),
        );

        const embedding: number[] = encodeResponse.data.embedding;
        const vectorLiteral = `[${embedding.join(',')}]`;

        // $executeRaw bắt buộc vì clip_embedding là Unsupported("vector(512)")
        // trong schema.prisma — Prisma Client không hỗ trợ update field này
        // qua cú pháp update() thông thường.
        await this.prisma.$executeRaw`
          UPDATE studio_sets
          SET clip_embedding = ${vectorLiteral}::vector
          WHERE id::text = ${set.id}
        `;
      } catch (err) {
        // Lỗi 1 ảnh (vd: avatar_url không phải ảnh thật, link chết...) không
        // được làm hỏng toàn bộ quá trình duyệt studio — chỉ ghi nhận cảnh báo.
        warnings.push(
          `Không thể encode ảnh cho set "${set.name}" (${set.id}): ${
            err instanceof Error ? err.message : 'lỗi không xác định'
          }`,
        );
      }
    }

    try {
      await firstValueFrom(this.http.post(`${aiServiceUrl}/reindex`, {}));
    } catch {
      warnings.push(
        'Không thể gọi /reindex ngay — FAISS index sẽ tự cập nhật ở lần khởi động AI Service tiếp theo',
      );
    }

    return warnings;
  }
}
