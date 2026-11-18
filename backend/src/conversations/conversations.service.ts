import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { MESSAGE_MAX_LENGTH } from './dto/send-message.dto';

/** Thông tin cần để dựng 1 dòng trong danh sách hội thoại. */
const conversationInclude = {
  user: { select: { id: true, full_name: true, avatar_url: true } },
  studio: {
    select: {
      id: true,
      name: true,
      owner_id: true,
      images: {
        orderBy: [
          { is_cover: 'desc' as const },
          { sort_order: 'asc' as const },
        ],
        take: 1,
        select: { url: true },
      },
    },
  },
  messages: {
    orderBy: { sent_at: 'desc' as const },
    take: 1,
    select: { content: true, sender_id: true, is_read: true, sent_at: true },
  },
};

type ConversationRow = {
  id: string;
  user_id: string;
  studio_id: string;
  last_message_at: Date | null;
  user: { id: string; full_name: string; avatar_url: string | null };
  studio: {
    id: string;
    name: string;
    owner_id: string;
    images: { url: string }[];
  };
  messages: {
    content: string;
    sender_id: string;
    is_read: boolean;
    sent_at: Date;
  }[];
};

/**
 * Nhắn tin giữa khách hàng và chủ studio.
 * - Mỗi cặp (khách, studio) có đúng 1 hội thoại; chủ studio là người nhận phía studio.
 * - Tin nhắn gửi qua REST hoặc socket đều đi qua sendMessage() -> lưu CSDL rồi đẩy
 *   sự kiện "message_received" tới phòng `user:<id>` của CẢ HAI người (mọi thiết bị).
 * - is_read của một tin = người nhận đã đọc; mở hội thoại thì đánh dấu đã đọc các tin
 *   của phía bên kia và báo "messages_read" cho người gửi.
 */
@Injectable()
export class ConversationsService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
  ) {}

  /** Khách bấm "Nhắn tin" ở trang studio: lấy hội thoại cũ hoặc tạo mới. */
  async findOrCreate(userId: string, studioId: string) {
    const studio = await this.prisma.studio.findUnique({
      where: { id: studioId },
      select: { id: true, status: true, owner_id: true },
    });
    if (!studio || studio.status !== 'active') {
      throw new NotFoundException(
        'Studio không tồn tại hoặc đang không hoạt động',
      );
    }
    if (studio.owner_id === userId) {
      throw new BadRequestException(
        'Không thể nhắn tin cho studio của chính mình',
      );
    }

    const existing = await this.prisma.conversation.findFirst({
      where: { user_id: userId, studio_id: studioId },
      select: { id: true },
    });
    const id =
      existing?.id ??
      (
        await this.prisma.conversation.create({
          data: { user_id: userId, studio_id: studioId },
          select: { id: true },
        })
      ).id;

    const row = await this.prisma.conversation.findUniqueOrThrow({
      where: { id },
      include: conversationInclude,
    });
    const unread = await this.countUnread(userId, [id]);
    return this.toSummary(row, userId, unread.get(id) ?? 0);
  }

  /**
   * Danh sách hội thoại của người đang đăng nhập (khách: theo user_id; chủ studio: theo
   * studio mình sở hữu). Chỉ lấy hội thoại đã có ít nhất 1 tin nhắn.
   */
  async findAllForUser(currentUserId: string) {
    const rows = await this.prisma.conversation.findMany({
      where: {
        last_message_at: { not: null },
        OR: [
          { user_id: currentUserId },
          { studio: { owner_id: currentUserId } },
        ],
      },
      orderBy: { last_message_at: 'desc' },
      include: conversationInclude,
    });
    const unread = await this.countUnread(
      currentUserId,
      rows.map((r) => r.id),
    );
    const data = rows.map((r) =>
      this.toSummary(
        r as ConversationRow,
        currentUserId,
        unread.get(r.id) ?? 0,
      ),
    );
    return {
      data,
      unread_total: data.reduce((sum, c) => sum + c.unread, 0),
    };
  }

  /** Tổng số tin chưa đọc (chấm đỏ trên nút Tin nhắn). */
  async unreadTotal(currentUserId: string) {
    const unread_total = await this.prisma.message.count({
      where: {
        is_read: false,
        sender_id: { not: currentUserId },
        conversation: {
          OR: [
            { user_id: currentUserId },
            { studio: { owner_id: currentUserId } },
          ],
        },
      },
    });
    return { unread_total };
  }

  /** Lịch sử tin nhắn, mới nhất trước. Tải trang đầu thì đánh dấu đã đọc. */
  async findMessages(
    conversationId: string,
    currentUserId: string,
    page = 1,
    limit = 30,
  ) {
    await this.ensureParticipant(conversationId, currentUserId);
    const take = Math.min(Math.max(limit, 1), 100);
    const skip = (Math.max(page, 1) - 1) * take;

    const [data, total] = await this.prisma.$transaction([
      this.prisma.message.findMany({
        where: { conversation_id: conversationId },
        skip,
        take,
        orderBy: { sent_at: 'desc' },
        select: {
          id: true,
          conversation_id: true,
          content: true,
          sender_id: true,
          is_read: true,
          sent_at: true,
        },
      }),
      this.prisma.message.count({ where: { conversation_id: conversationId } }),
    ]);

    if (page <= 1) await this.markRead(conversationId, currentUserId);
    return { data, total, page, limit: take };
  }

  /** Đánh dấu đã đọc mọi tin của phía bên kia trong hội thoại. */
  async markRead(conversationId: string, currentUserId: string) {
    const conv = await this.ensureParticipant(conversationId, currentUserId);
    const { count } = await this.prisma.message.updateMany({
      where: {
        conversation_id: conversationId,
        sender_id: { not: currentUserId },
        is_read: false,
      },
      data: { is_read: true },
    });
    if (count > 0) {
      const partnerId =
        conv.user_id === currentUserId ? conv.studio.owner_id : conv.user_id;
      this.realtime.emitToUsers([partnerId], 'messages_read', {
        conversation_id: conversationId,
        reader_id: currentUserId,
      });
    }
    return this.unreadTotal(currentUserId);
  }

  async sendMessage(
    conversationId: string,
    senderId: string,
    rawContent: string,
  ) {
    const content = typeof rawContent === 'string' ? rawContent.trim() : '';
    if (!content) throw new BadRequestException('Tin nhắn không được để trống');
    if (content.length > MESSAGE_MAX_LENGTH) {
      throw new BadRequestException(
        `Tin nhắn tối đa ${MESSAGE_MAX_LENGTH} ký tự`,
      );
    }
    const conv = await this.ensureParticipant(conversationId, senderId);

    const sentAt = new Date();
    const [message] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversation_id: conversationId,
          sender_id: senderId,
          content,
          sent_at: sentAt,
        },
        select: {
          id: true,
          conversation_id: true,
          content: true,
          sender_id: true,
          is_read: true,
          sent_at: true,
        },
      }),
      this.prisma.conversation.update({
        where: { id: conversationId },
        data: { last_message_at: sentAt },
      }),
    ]);

    this.realtime.emitToUsers(
      [conv.user_id, conv.studio.owner_id],
      'message_received',
      message,
    );
    return message;
  }

  // Dùng bởi ChatGateway để kiểm tra quyền vào phòng hội thoại
  async getParticipantUserIds(conversationId: string): Promise<string[]> {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { studio: { select: { owner_id: true } } },
    });
    if (!conversation) return [];
    return [conversation.user_id, conversation.studio.owner_id];
  }

  // ---------------------------------------------------------------------------

  private async ensureParticipant(conversationId: string, userId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { studio: { select: { owner_id: true } } },
    });
    if (!conversation) {
      throw new NotFoundException('Cuộc trò chuyện không tồn tại');
    }
    const isParticipant =
      conversation.user_id === userId ||
      conversation.studio.owner_id === userId;
    if (!isParticipant) {
      throw new ForbiddenException('Bạn không thuộc cuộc trò chuyện này');
    }
    return conversation;
  }

  /** Số tin chưa đọc theo từng hội thoại (tin do phía bên kia gửi). */
  private async countUnread(userId: string, conversationIds: string[]) {
    const map = new Map<string, number>();
    if (conversationIds.length === 0) return map;
    const groups = await this.prisma.message.groupBy({
      by: ['conversation_id'],
      where: {
        conversation_id: { in: conversationIds },
        is_read: false,
        sender_id: { not: userId },
      },
      _count: { _all: true },
    });
    for (const g of groups) map.set(g.conversation_id, g._count._all);
    return map;
  }

  /** "partner" là phía còn lại: khách thấy studio, chủ studio thấy khách. */
  private toSummary(c: ConversationRow, currentUserId: string, unread: number) {
    const isCustomer = c.user_id === currentUserId;
    return {
      id: c.id,
      studio_id: c.studio_id,
      studio_name: c.studio.name,
      my_role: isCustomer ? ('customer' as const) : ('owner' as const),
      last_message_at: c.last_message_at,
      partner: isCustomer
        ? {
            id: c.studio.owner_id,
            name: c.studio.name,
            avatar: c.studio.images[0]?.url ?? null,
          }
        : { id: c.user.id, name: c.user.full_name, avatar: c.user.avatar_url },
      last_message: c.messages[0] ?? null,
      unread,
    };
  }
}
