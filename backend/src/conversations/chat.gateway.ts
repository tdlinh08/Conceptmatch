import { Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ConversationsService } from './conversations.service';

interface AuthenticatedSocket extends Socket {
  data: {
    userId: string;
    role: string;
  };
}

/**
 * Khớp với API Contract: "ws://localhost:3000 — kết nối kèm ?token=<access_token>".
 * Không set namespace/path riêng -> mặc định lắng nghe ngay tại gốc, đúng
 * địa chỉ ws://localhost:3000 (KHÔNG có prefix /api/v1 — setGlobalPrefix của
 * NestJS chỉ áp dụng cho route HTTP thường, không áp dụng cho WebSocket Gateway).
 */
@WebSocketGateway({ cors: { origin: '*' } })
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;

  private readonly logger = new Logger(ChatGateway.name);

  constructor(
    private jwt: JwtService,
    private config: ConfigService,
    private conversationsService: ConversationsService,
  ) {}

  async handleConnection(client: AuthenticatedSocket) {
    try {
      const token = client.handshake.query.token as string | undefined;
      if (!token) {
        throw new UnauthorizedException('Thiếu token');
      }

      const payload = await this.jwt.verifyAsync<{ sub: string; role: string }>(
        token,
        { secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET') },
      );

      client.data.userId = payload.sub;
      client.data.role = payload.role;

      // Mỗi user tự động join 1 "room" riêng theo user_id — dùng để đẩy thông
      // báo booking_status_changed đích danh tới đúng người, không cần biết
      // trước socket.id (vì 1 user có thể mở nhiều tab/thiết bị cùng lúc).
      await client.join(`user:${payload.sub}`);
      this.logger.log(`Client connected: user ${payload.sub}`);
    } catch {
      client.emit('error', { message: 'Token không hợp lệ, kết nối bị từ chối' });
      client.disconnect(true);
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    this.logger.log(`Client disconnected: user ${client.data?.userId ?? 'unknown'}`);
  }

  /**
   * Bổ sung so với API Contract gốc (chỉ định nghĩa send_message/
   * message_received) — cần thêm event này để client báo cho server biết
   * "đang mở đúng cuộc trò chuyện nào", nhờ đó server chỉ đẩy tin nhắn realtime
   * cho đúng 2 người trong room `conversation:{id}`, tránh gửi lan sang các
   * cuộc trò chuyện không liên quan.
   */
  @SubscribeMessage('join_conversation')
  async handleJoinConversation(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversation_id: string },
  ) {
    const participantIds = await this.conversationsService.getParticipantUserIds(
      data.conversation_id,
    );
    if (!participantIds.includes(client.data.userId)) {
      client.emit('error', { message: 'Bạn không thuộc cuộc trò chuyện này' });
      return;
    }
    await client.join(`conversation:${data.conversation_id}`);
  }

  @SubscribeMessage('send_message')
  async handleSendMessage(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversation_id: string; content: string },
  ) {
    try {
      const message = await this.conversationsService.sendMessage(
        data.conversation_id,
        client.data.userId,
        data.content,
      );

      this.server
        .to(`conversation:${data.conversation_id}`)
        .emit('message_received', message);

      return message;
    } catch (err) {
      client.emit('error', {
        message: err instanceof Error ? err.message : 'Gửi tin nhắn thất bại',
      });
    }
  }

  /**
   * KHÔNG phải WebSocket event nhận từ client — đây là method thường, được
   * BookingsService gọi trực tiếp (qua dependency injection) mỗi khi trạng
   * thái booking thay đổi, để đẩy sự kiện "booking_status_changed" real-time
   * đúng theo API Contract.
   */
  emitBookingStatusChanged(
    recipientUserId: string,
    payload: { booking_id: string; status: string; studio_name: string },
  ) {
    this.server.to(`user:${recipientUserId}`).emit('booking_status_changed', payload);
  }
}
