import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AdminService } from '../admin/admin.service';
import { recomputeStudioRating } from '../reviews/rating';
import { CreateReportDto, QueryReportsDto, ResolveReportDto } from './dto/report.dto';

/**
 * Báo cáo vi phạm (SRS 3.4.3 "số báo cáo vi phạm chờ xử lý") + kiểm duyệt đánh giá.
 * Khách / chủ studio báo cáo 1 studio hoặc 1 đánh giá -> hàng chờ của admin ->
 * admin ẩn đánh giá / gỡ studio / bỏ qua; người báo cáo nhận thông báo kết quả.
 */
@Injectable()
export class ReportsService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private admin: AdminService,
  ) {}

  async create(reporterId: string, dto: CreateReportDto) {
    if (dto.target_type === 'studio') {
      const studio = await this.prisma.studio.findUnique({
        where: { id: dto.target_id },
        select: { status: true, owner_id: true },
      });
      if (!studio || studio.status !== 'active') throw new NotFoundException('Studio không tồn tại');
      if (studio.owner_id === reporterId) throw new BadRequestException('Không thể báo cáo studio của chính mình');
    } else {
      const review = await this.prisma.review.findUnique({
        where: { id: dto.target_id },
        select: { user_id: true, is_hidden: true },
      });
      if (!review || review.is_hidden) throw new NotFoundException('Đánh giá không tồn tại');
      if (review.user_id === reporterId) throw new BadRequestException('Không thể báo cáo đánh giá của chính mình');
    }
    const dup = await this.prisma.report.findFirst({
      where: { reporter_id: reporterId, target_type: dto.target_type, target_id: dto.target_id, status: 'pending' },
    });
    if (dup) throw new ConflictException('Bạn đã báo cáo nội dung này, quản trị viên đang xem xét');

    const report = await this.prisma.report.create({
      data: {
        reporter_id: reporterId,
        target_type: dto.target_type,
        target_id: dto.target_id,
        reason: dto.reason.trim(),
        detail: dto.detail?.trim() || null,
      },
    });
    return { id: report.id, status: report.status, message: 'Đã gửi báo cáo, cảm ơn bạn!' };
  }

  async findAll(q: QueryReportsDto) {
    const where: Prisma.ReportWhereInput = {
      ...(q.status && { status: q.status }),
      ...(q.target_type && { target_type: q.target_type }),
    };
    const [rows, total, pendingCount] = await this.prisma.$transaction([
      this.prisma.report.findMany({
        where,
        skip: (q.page - 1) * q.limit,
        take: q.limit,
        // chờ xử lý: cũ nhất lên đầu; đã xử lý: mới nhất lên đầu
        orderBy: { created_at: q.status === 'pending' ? 'asc' : 'desc' },
        include: {
          reporter: { select: { id: true, full_name: true, email: true, role: true } },
          handler: { select: { full_name: true } },
        },
      }),
      this.prisma.report.count({ where }),
      this.prisma.report.count({ where: { status: 'pending' } }),
    ]);

    // Gắn nội dung bị báo cáo để admin đọc ngay
    const studioIds = rows.filter((r) => r.target_type === 'studio').map((r) => r.target_id);
    const reviewIds = rows.filter((r) => r.target_type === 'review').map((r) => r.target_id);
    const [studios, reviews, sameTarget] = await Promise.all([
      this.prisma.studio.findMany({
        where: { id: { in: studioIds } },
        select: { id: true, name: true, status: true, district: true },
      }),
      this.prisma.review.findMany({
        where: { id: { in: reviewIds } },
        select: {
          id: true,
          stars: true,
          comment: true,
          is_hidden: true,
          created_at: true,
          user: { select: { full_name: true } },
          studio: { select: { id: true, name: true } },
        },
      }),
      this.prisma.report.groupBy({
        by: ['target_id'],
        where: { target_id: { in: [...studioIds, ...reviewIds] } },
        _count: { _all: true },
        orderBy: { target_id: 'asc' },
      }),
    ]);
    const studioById = new Map(studios.map((s) => [s.id, s]));
    const reviewById = new Map(reviews.map((r) => [r.id, r]));
    const countById = new Map(sameTarget.map((c) => [c.target_id, (c._count as { _all: number })._all]));

    return {
      data: rows.map((r) => ({
        id: r.id,
        target_type: r.target_type,
        target_id: r.target_id,
        reason: r.reason,
        detail: r.detail,
        status: r.status,
        admin_note: r.admin_note,
        handled_by: r.handler?.full_name ?? null,
        handled_at: r.handled_at,
        created_at: r.created_at,
        reporter: r.reporter,
        reports_on_target: countById.get(r.target_id) ?? 1, // tổng số lần nội dung này bị báo cáo
        studio: r.target_type === 'studio' ? (studioById.get(r.target_id) ?? null) : null,
        review: r.target_type === 'review' ? (reviewById.get(r.target_id) ?? null) : null,
      })),
      total,
      pending_count: pendingCount,
      page: q.page,
      limit: q.limit,
    };
  }

  /** Xử lý: ẩn đánh giá / gỡ studio / chỉ ghi nhận. Mọi báo cáo đang chờ cùng nội dung được đóng theo. */
  async resolve(id: string, adminId: string, dto: ResolveReportDto) {
    const report = await this.pendingReport(id);
    if (dto.action === 'hide_review') {
      if (report.target_type !== 'review') throw new BadRequestException('Báo cáo này không phải về đánh giá');
      await this.hideReview(report.target_id, adminId, dto.note);
    }
    if (dto.action === 'take_down') {
      if (report.target_type !== 'studio') throw new BadRequestException('Báo cáo này không phải về studio');
      const studio = await this.prisma.studio.findUnique({ where: { id: report.target_id } });
      if (studio?.status === 'active') {
        await this.admin.takeDownStudio(report.target_id, adminId, { reason: dto.note });
      }
    }
    return this.close(report, 'resolved', adminId, dto.note);
  }

  async dismiss(id: string, adminId: string, note?: string) {
    const report = await this.pendingReport(id);
    return this.close(report, 'dismissed', adminId, note?.trim() || 'Không phát hiện vi phạm');
  }

  // ---- Kiểm duyệt đánh giá ----

  async hideReview(reviewId: string, adminId: string, reason: string) {
    const review = await this.prisma.review.findUnique({ where: { id: reviewId } });
    if (!review) throw new NotFoundException('Đánh giá không tồn tại');
    if (review.is_hidden) return { id: reviewId, is_hidden: true };
    await this.prisma.$transaction(async (tx) => {
      await tx.review.update({ where: { id: reviewId }, data: { is_hidden: true, hidden_reason: reason } });
      await recomputeStudioRating(tx, review.studio_id); // không tính đánh giá bị ẩn
    });
    await this.prisma.auditLog.create({
      data: { admin_id: adminId, action: 'Ẩn đánh giá', target_type: 'review', target_id: reviewId, note: reason },
    });
    return { id: reviewId, is_hidden: true };
  }

  async unhideReview(reviewId: string, adminId: string) {
    const review = await this.prisma.review.findUnique({ where: { id: reviewId } });
    if (!review) throw new NotFoundException('Đánh giá không tồn tại');
    if (!review.is_hidden) return { id: reviewId, is_hidden: false };
    await this.prisma.$transaction(async (tx) => {
      await tx.review.update({ where: { id: reviewId }, data: { is_hidden: false, hidden_reason: null } });
      await recomputeStudioRating(tx, review.studio_id);
    });
    await this.prisma.auditLog.create({
      data: { admin_id: adminId, action: 'Hiện lại đánh giá', target_type: 'review', target_id: reviewId },
    });
    return { id: reviewId, is_hidden: false };
  }

  // ---- tiện ích ----

  private async pendingReport(id: string) {
    const report = await this.prisma.report.findUnique({ where: { id } });
    if (!report) throw new NotFoundException('Báo cáo không tồn tại');
    if (report.status !== 'pending') throw new ConflictException('Báo cáo đã được xử lý');
    return report;
  }

  private async close(
    report: { id: string; target_type: 'studio' | 'review'; target_id: string },
    status: 'resolved' | 'dismissed',
    adminId: string,
    note: string,
  ) {
    const open = await this.prisma.report.findMany({
      where: { target_type: report.target_type, target_id: report.target_id, status: 'pending' },
      select: { id: true, reporter_id: true },
    });
    await this.prisma.report.updateMany({
      where: { id: { in: open.map((r) => r.id) } },
      data: { status, admin_note: note, handled_by: adminId, handled_at: new Date() },
    });
    await this.prisma.auditLog.create({
      data: {
        admin_id: adminId,
        action: status === 'resolved' ? 'Xử lý báo cáo' : 'Bỏ qua báo cáo',
        target_type: report.target_type,
        target_id: report.target_id,
        note,
      },
    });
    const what = report.target_type === 'studio' ? 'studio' : 'đánh giá';
    for (const r of new Map(open.map((o) => [o.reporter_id, o])).values()) {
      await this.notifications.notify({
        recipientId: r.reporter_id,
        type: 'report_handled',
        title: status === 'resolved' ? 'Báo cáo của bạn đã được xử lý' : 'Báo cáo của bạn đã được xem xét',
        body:
          status === 'resolved'
            ? `Quản trị viên đã xử lý ${what} bạn báo cáo. Cảm ơn bạn đã góp ý!`
            : `Quản trị viên chưa thấy ${what} bạn báo cáo vi phạm quy định. Ghi chú: ${note}`,
        refId: report.target_id,
      });
    }
    return { id: report.id, status, closed: open.length };
  }
}
