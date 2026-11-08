import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StatRange } from './dto/query-stats.dto';

/** 1 cột trong biểu đồ (1 ngày hoặc 1 tháng). */
export interface Bucket {
  key: string; // "2026-11-07" hoặc "2026-11"
  label: string; // "07/11" hoặc "T11/26"
  bookings: number; // đơn MỚI tạo trong ngày/tháng
  revenue: number; // tổng tiền đơn HOÀN THÀNH có buổi chụp trong ngày/tháng
  new_users: number; // (chỉ admin) tài khoản mới
}

/**
 * Thống kê cho trang admin (toàn sàn) và màn Doanh thu của chủ studio.
 * Quy ước:
 *  - "Đơn" = số đơn được TẠO trong kỳ (mọi trạng thái).
 *  - "Doanh thu" = tổng tiền các đơn HOÀN THÀNH, tính theo NGÀY CHỤP (start_time).
 *  - Gom theo ngày/tháng theo giờ Việt Nam (APP_TZ), không phải giờ UTC của máy chủ DB.
 */
@Injectable()
export class StatsService {
  private readonly tz = process.env.APP_TZ || 'Asia/Ho_Chi_Minh';

  constructor(private prisma: PrismaService) {}

  // ---------------------------------------------------------------- khung thời gian

  /** Mốc bắt đầu kỳ (giờ máy, đã đặt TZ VN) + danh sách cột rỗng. */
  private frame(range: StatRange) {
    const now = new Date();
    const buckets: Bucket[] = [];
    let from: Date;
    const two = (n: number) => String(n).padStart(2, '0');
    if (range === '12m') {
      from = new Date(now.getFullYear(), now.getMonth() - 11, 1);
      for (let i = 0; i < 12; i++) {
        const d = new Date(from.getFullYear(), from.getMonth() + i, 1);
        buckets.push({
          key: `${d.getFullYear()}-${two(d.getMonth() + 1)}`,
          label: `T${d.getMonth() + 1}/${String(d.getFullYear()).slice(2)}`,
          bookings: 0,
          revenue: 0,
          new_users: 0,
        });
      }
    } else {
      const days = range === '7d' ? 7 : 30;
      from = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (days - 1));
      for (let i = 0; i < days; i++) {
        const d = new Date(from.getFullYear(), from.getMonth(), from.getDate() + i);
        buckets.push({
          key: `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())}`,
          label: `${two(d.getDate())}/${two(d.getMonth() + 1)}`,
          bookings: 0,
          revenue: 0,
          new_users: 0,
        });
      }
    }
    return { from, unit: range === '12m' ? 'month' : 'day', buckets };
  }

  /**
   * Cột thời gian đã đổi sang giờ VN rồi cắt theo ngày/tháng, trả về chuỗi khoá.
   * Cột DB là timestamp (UTC, không múi giờ) -> AT TIME ZONE 'UTC' rồi AT TIME ZONE tz.
   */
  private bucketExpr(column: string, unit: string) {
    const fmt = unit === 'month' ? 'YYYY-MM' : 'YYYY-MM-DD';
    return Prisma.raw(
      `to_char(date_trunc('${unit}', (${column} AT TIME ZONE 'UTC') AT TIME ZONE '${this.tz}'), '${fmt}')`,
    );
  }

  /** Mốc thời gian dạng chuỗi UTC để so với cột timestamp (không phụ thuộc múi giờ phiên DB). */
  private utc(d: Date) {
    return d.toISOString().replace('T', ' ').replace('Z', '');
  }

  private studioFilter(studioIds?: string[]) {
    return studioIds ? Prisma.sql`AND b.studio_id IN (${Prisma.join(studioIds)})` : Prisma.empty;
  }

  private async series(range: StatRange, studioIds?: string[], withUsers = false) {
    const { from, unit, buckets } = this.frame(range);
    const fromUtc = this.utc(from);
    const byKey = new Map(buckets.map((b) => [b.key, b]));
    const filter = this.studioFilter(studioIds);

    const created = await this.prisma.$queryRaw<{ k: string; n: bigint }[]>(Prisma.sql`
      SELECT ${this.bucketExpr('b.created_at', unit)} AS k, COUNT(*) AS n
      FROM bookings b
      WHERE b.created_at >= ${fromUtc}::timestamp ${filter}
      GROUP BY 1`);
    for (const r of created) {
      const b = byKey.get(r.k);
      if (b) b.bookings = Number(r.n);
    }

    const revenue = await this.prisma.$queryRaw<{ k: string; s: Prisma.Decimal | null }[]>(Prisma.sql`
      SELECT ${this.bucketExpr('b.start_time', unit)} AS k, SUM(b.total_amount) AS s
      FROM bookings b
      WHERE b.status = 'completed' AND b.start_time >= ${fromUtc}::timestamp ${filter}
      GROUP BY 1`);
    for (const r of revenue) {
      const b = byKey.get(r.k);
      if (b) b.revenue = Number(r.s ?? 0);
    }

    if (withUsers) {
      const users = await this.prisma.$queryRaw<{ k: string; n: bigint }[]>(Prisma.sql`
        SELECT ${this.bucketExpr('u.created_at', unit)} AS k, COUNT(*) AS n
        FROM users u
        WHERE u.created_at >= ${fromUtc}::timestamp
        GROUP BY 1`);
      for (const r of users) {
        const b = byKey.get(r.k);
        if (b) b.new_users = Number(r.n);
      }
    }
    return { from, fromUtc, buckets };
  }

  /** Đơn theo concept (style_tag của bối cảnh) và theo quận của studio. */
  private async breakdowns(fromUtc: string, studioIds?: string[]) {
    const filter = this.studioFilter(studioIds);
    const concepts = await this.prisma.$queryRaw<{ name: string | null; n: bigint }[]>(Prisma.sql`
      SELECT s.style_tag AS name, COUNT(*) AS n
      FROM bookings b JOIN studio_sets s ON s.id = b.set_id
      WHERE b.created_at >= ${fromUtc}::timestamp ${filter}
      GROUP BY s.style_tag ORDER BY n DESC LIMIT 8`);
    const districts = await this.prisma.$queryRaw<{ name: string; n: bigint }[]>(Prisma.sql`
      SELECT st.district AS name, COUNT(*) AS n
      FROM bookings b JOIN studios st ON st.id = b.studio_id
      WHERE b.created_at >= ${fromUtc}::timestamp ${filter}
      GROUP BY st.district ORDER BY n DESC LIMIT 8`);
    return {
      top_concepts: concepts.map((c) => ({ name: c.name ?? '(chưa đặt concept)', bookings: Number(c.n) })),
      top_districts: districts.map((d) => ({ name: d.name, bookings: Number(d.n) })),
    };
  }

  /** Trạng thái các đơn tạo trong kỳ. */
  private async statusCounts(from: Date, studioIds?: string[]) {
    const rows = await this.prisma.booking.groupBy({
      by: ['status'],
      where: { created_at: { gte: from }, ...(studioIds && { studio_id: { in: studioIds } }) },
      _count: { _all: true },
    });
    return Object.fromEntries(rows.map((r) => [r.status, r._count._all])) as Record<string, number>;
  }

  private totals(buckets: Bucket[], status: Record<string, number>) {
    const bookings = buckets.reduce((s, b) => s + b.bookings, 0);
    const revenue = buckets.reduce((s, b) => s + b.revenue, 0);
    const completed = status.completed ?? 0;
    const lost = (status.cancelled ?? 0) + (status.rejected ?? 0) + (status.no_show ?? 0);
    return {
      bookings,
      revenue,
      completed,
      // Tỉ lệ đơn bị huỷ / từ chối / khách không đến trên tổng đơn trong kỳ
      lost_rate: bookings ? Math.round((lost / bookings) * 1000) / 10 : 0,
      avg_order_value: completed ? Math.round(revenue / completed) : 0,
    };
  }

  // ---------------------------------------------------------------- công khai

  /** Toàn sàn (admin). */
  async forAdmin(range: StatRange) {
    const { from, fromUtc, buckets } = await this.series(range, undefined, true);
    const status = await this.statusCounts(from);
    const top = await this.prisma.booking.groupBy({
      by: ['studio_id'],
      where: { status: 'completed', start_time: { gte: from } },
      _sum: { total_amount: true },
      _count: { _all: true },
      orderBy: { _sum: { total_amount: 'desc' } },
      take: 10,
    });
    const studios = await this.prisma.studio.findMany({
      where: { id: { in: top.map((t) => t.studio_id) } },
      select: { id: true, name: true, district: true, avg_rating: true },
    });
    const byId = new Map(studios.map((s) => [s.id, s]));
    return {
      range,
      series: buckets,
      totals: {
        ...this.totals(buckets, status),
        new_users: buckets.reduce((s, b) => s + b.new_users, 0),
      },
      status_counts: status,
      top_studios: top.map((t) => ({
        id: t.studio_id,
        name: byId.get(t.studio_id)?.name ?? '(đã xoá)',
        district: byId.get(t.studio_id)?.district ?? '',
        avg_rating: Number(byId.get(t.studio_id)?.avg_rating ?? 0),
        completed: t._count._all,
        revenue: Number(t._sum.total_amount ?? 0),
      })),
      ...(await this.breakdowns(fromUtc)),
    };
  }

  /** Studio của 1 chủ (tất cả hoặc 1 studio). */
  async forOwner(ownerId: string, range: StatRange, studioId?: string) {
    const mine = await this.prisma.studio.findMany({
      where: { owner_id: ownerId },
      select: { id: true, name: true, avg_rating: true, review_count: true },
    });
    if (studioId && !mine.some((s) => s.id === studioId)) {
      throw new ForbiddenException('Bạn không có quyền xem thống kê studio này');
    }
    const ids = studioId ? [studioId] : mine.map((s) => s.id);
    if (ids.length === 0) ids.push('00000000-0000-0000-0000-000000000000'); // chưa có studio -> số 0

    const { from, fromUtc, buckets } = await this.series(range, ids);
    const status = await this.statusCounts(from, ids);

    // Bối cảnh được đặt nhiều nhất trong kỳ (+ doanh thu đơn hoàn thành)
    const [bySet, revBySet] = await Promise.all([
      this.prisma.booking.groupBy({
        by: ['set_id'],
        where: { studio_id: { in: ids }, created_at: { gte: from } },
        _count: { _all: true },
        orderBy: { _count: { set_id: 'desc' } },
        take: 8,
      }),
      this.prisma.booking.groupBy({
        by: ['set_id'],
        where: { studio_id: { in: ids }, status: 'completed', start_time: { gte: from } },
        _sum: { total_amount: true },
      }),
    ]);
    const sets = await this.prisma.studioSet.findMany({
      where: { id: { in: bySet.map((s) => s.set_id) } },
      select: { id: true, name: true, studio: { select: { name: true } } },
    });
    const setById = new Map(sets.map((s) => [s.id, s]));
    const revById = new Map(revBySet.map((r) => [r.set_id, Number(r._sum.total_amount ?? 0)]));

    const scoped = mine.filter((s) => ids.includes(s.id));
    const reviewCount = scoped.reduce((s, x) => s + x.review_count, 0);
    const avgRating = reviewCount
      ? scoped.reduce((s, x) => s + Number(x.avg_rating) * x.review_count, 0) / reviewCount
      : 0;

    return {
      range,
      series: buckets.map(({ new_users: _, ...b }) => b),
      totals: {
        ...this.totals(buckets, status),
        avg_rating: Math.round(avgRating * 10) / 10,
        review_count: reviewCount,
      },
      status_counts: status,
      top_sets: bySet.map((s) => ({
        id: s.set_id,
        name: setById.get(s.set_id)?.name ?? '',
        studio_name: setById.get(s.set_id)?.studio.name ?? '',
        bookings: s._count._all,
        revenue: revById.get(s.set_id) ?? 0,
      })),
      ...(await this.breakdowns(fromUtc, ids)),
    };
  }
}
