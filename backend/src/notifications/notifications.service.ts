import { Injectable, NotFoundException } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/** Giờ hiển thị trong nội dung thông báo: "09:30 11/11" (giờ máy chủ = giờ VN). */
export function shortTime(d: Date): string {
  const two = (n: number) => String(n).padStart(2, '0');
  return `${two(d.getHours())}:${two(d.getMinutes())} ${two(d.getDate())}/${two(d.getMonth() + 1)}`;
}

/**
 * Thông báo trong app (chuông ở Home). Ghi vào bảng notifications khi có sự kiện
 * đơn đặt / đánh giá / duyệt studio; app đọc danh sách + số chưa đọc.
 */
@Injectable()
export class NotificationsService {
  constructor(private prisma: PrismaService) {}

  /**
   * Ghi 1 thông báo. KHÔNG ném lỗi: gửi thông báo hỏng không được làm hỏng
   * thao tác chính (đặt lịch, xác nhận…) vốn đã thành công.
   */
  async notify(data: {
    recipientId: string;
    type: NotificationType;
    title: string;
    body: string;
    refId?: string;
  }): Promise<void> {
    try {
      await this.prisma.notification.create({
        data: {
          recipient_id: data.recipientId,
          type: data.type,
          title: data.title.slice(0, 150),
          body: data.body,
          ref_id: data.refId,
        },
      });
    } catch {
      // bỏ qua có chủ đích
    }
  }

  async findMine(userId: string, page = 1, limit = 20) {
    const where = { recipient_id: userId };
    const [data, total, unread] = await this.prisma.$transaction([
      this.prisma.notification.findMany({
        where,
        orderBy: { created_at: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          type: true,
          title: true,
          body: true,
          ref_id: true,
          is_read: true,
          created_at: true,
        },
      }),
      this.prisma.notification.count({ where }),
      this.prisma.notification.count({ where: { ...where, is_read: false } }),
    ]);
    return { data, total, unread };
  }

  async unreadCount(userId: string) {
    const unread = await this.prisma.notification.count({
      where: { recipient_id: userId, is_read: false },
    });
    return { unread };
  }

  async markRead(id: string, userId: string) {
    const { count } = await this.prisma.notification.updateMany({
      where: { id, recipient_id: userId },
      data: { is_read: true },
    });
    if (count === 0) throw new NotFoundException('Thông báo không tồn tại');
    return this.unreadCount(userId);
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { recipient_id: userId, is_read: false },
      data: { is_read: true },
    });
    return { unread: 0 };
  }
}
