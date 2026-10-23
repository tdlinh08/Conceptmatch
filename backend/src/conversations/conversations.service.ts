import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ConversationsService {
  constructor(private prisma: PrismaService) {}

  async findOrCreate(userId: string, studioId: string) {
    const studio = await this.prisma.studio.findUnique({
      where: { id: studioId },
    });
    if (!studio) {
      throw new NotFoundException('Studio không tồn tại');
    }

    let conversation = await this.prisma.conversation.findFirst({
      where: { user_id: userId, studio_id: studioId },
    });

    if (!conversation) {
      conversation = await this.prisma.conversation.create({
        data: { user_id: userId, studio_id: studioId },
      });
    }

    return conversation;
  }

  async findAllForUser(currentUserId: string) {
    const conversations = await this.prisma.conversation.findMany({
      where: {
        OR: [{ user_id: currentUserId }, { studio: { owner_id: currentUserId } }],
      },
      orderBy: { last_message_at: 'desc' },
      include: {
        user: { select: { id: true, full_name: true, avatar_url: true } },
        studio: { select: { id: true, name: true, owner_id: true } },
        messages: {
          orderBy: { sent_at: 'desc' },
          take: 1,
          select: { content: true, is_read: true },
        },
      },
    });

    return {
      data: conversations.map((c) => {
        // "partner" là phía còn lại trong cuộc trò chuyện: nếu người xem là
        // Customer thì partner hiển thị là Studio, và ngược lại.
        const isCustomer = c.user_id === currentUserId;
        return {
          id: c.id,
          last_message_at: c.last_message_at,
          partner: isCustomer
            ? { id: c.studio.id, name: c.studio.name, avatar: null }
            : { id: c.user.id, name: c.user.full_name, avatar: c.user.avatar_url },
          last_message: c.messages[0] ?? null,
        };
      }),
    };
  }

  async findMessages(
    conversationId: string,
    currentUserId: string,
    page = 1,
    limit = 20,
  ) {
    await this.ensureParticipant(conversationId, currentUserId);

    const [data, total] = await this.prisma.$transaction([
      this.prisma.message.findMany({
        where: { conversation_id: conversationId },
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { sent_at: 'desc' },
        select: {
          id: true,
          content: true,
          sender_id: true,
          is_read: true,
          sent_at: true,
        },
      }),
      this.prisma.message.count({ where: { conversation_id: conversationId } }),
    ]);

    return { data, total };
  }

  async sendMessage(conversationId: string, senderId: string, content: string) {
    await this.ensureParticipant(conversationId, senderId);

    const message = await this.prisma.message.create({
      data: { conversation_id: conversationId, sender_id: senderId, content },
    });

    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: { last_message_at: new Date() },
    });

    return {
      id: message.id,
      conversation_id: message.conversation_id,
      content: message.content,
      sender_id: message.sender_id,
      sent_at: message.sent_at,
    };
  }

  // Dùng bởi ChatGateway để biết cần join/emit socket cho những user_id nào
  async getParticipantUserIds(conversationId: string): Promise<string[]> {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { studio: { select: { owner_id: true } } },
    });
    if (!conversation) return [];
    return [conversation.user_id, conversation.studio.owner_id];
  }

  private async ensureParticipant(conversationId: string, userId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { studio: { select: { owner_id: true } } },
    });
    if (!conversation) {
      throw new NotFoundException('Conversation không tồn tại');
    }
    const isParticipant =
      conversation.user_id === userId || conversation.studio.owner_id === userId;
    if (!isParticipant) {
      throw new ForbiddenException('Bạn không có quyền truy cập conversation này');
    }
    return conversation;
  }
}
