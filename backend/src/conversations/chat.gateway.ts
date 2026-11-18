import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { ConversationsService } from './conversations.service';

interface AuthenticatedSocket extends Socket {
  data: {
    userId: string;
    role: string;
  };
}

/**
 * Cổng Socket.IO dùng chung cho chat và thông báo real-time.
 * Địa chỉ: ws://<máy chủ>:3000 (KHÔNG có prefix /api/v1 — setGlobalPrefix chỉ áp dụng
 * cho route HTTP). Kết nối kèm access token: `auth: { token }` hoặc `?token=<access_token>`.
 *
 * Sự kiện server -> client (đều gửi tới phòng `user:<id>`):
 * - message_received        tin nhắn mới (cả người gửi lẫn người nhận đều nhận)
 * - messages_read           phía bên kia đã đọc tin trong 1 hội thoại
 * - notification_created    có thông báo mới (đơn đặt, đánh giá, duyệt studio…)
 * - booking_status_changed  trạng thái đơn đặt thay đổi
 * Sự kiện client -> server: send_message, join_conversation (giữ cho tương thích).
 */
@WebSocketGateway({ cors: { origin: '*' } })
export class ChatGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer() server: Server;

  private readonly logger = new Logger(ChatGateway.name);

  constructor(
    private jwt: JwtService,
    private config: ConfigService,
    private prisma: PrismaService,
    private realtime: RealtimeService,
    private conversationsService: ConversationsService,
  ) {}

  afterInit(server: Server) {
    this.realtime.attach(server);
  }

  async handleConnection(client: AuthenticatedSocket) {
    try {
      const auth = client.handshake.auth as { token?: unknown } | undefined;
      const token =
        (typeof auth?.token === 'string' ? auth.token : undefined) ??
        (client.handshake.query.token as string | undefined);
      if (!token) throw new Error('Thiếu token');

      const payload = await this.jwt.verifyAsync<{ sub: string; role: string }>(
        token,
        { secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET') },
      );
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        select: { status: true },
      });
      if (!user || user.status === 'locked')
        throw new Error('Tài khoản không hợp lệ');

      client.data.userId = payload.sub;
      client.data.role = payload.role;
      // Mỗi người dùng có 1 phòng riêng -> gửi tới mọi thiết bị đang mở của người đó.
      await client.join(`user:${payload.sub}`);
      this.logger.log(`Client connected: user ${payload.sub}`);
    } catch {
      client.emit('auth_error', {
        message: 'Token không hợp lệ, kết nối bị từ chối',
      });
      client.disconnect(true);
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    this.logger.log(
      `Client disconnected: user ${client.data?.userId ?? 'unknown'}`,
    );
  }

  @SubscribeMessage('join_conversation')
  async handleJoinConversation(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversation_id: string },
  ) {
    const participantIds =
      await this.conversationsService.getParticipantUserIds(
        data?.conversation_id,
      );
    if (!participantIds.includes(client.data.userId)) {
      return { ok: false, message: 'Bạn không thuộc cuộc trò chuyện này' };
    }
    await client.join(`conversation:${data.conversation_id}`);
    return { ok: true };
  }

  /** Gửi tin qua socket. Kết quả trả về qua ack; tin mới được phát bởi ConversationsService. */
  @SubscribeMessage('send_message')
  async handleSendMessage(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversation_id: string; content: string },
  ) {
    try {
      const message = await this.conversationsService.sendMessage(
        data?.conversation_id,
        client.data.userId,
        data?.content,
      );
      return { ok: true, message };
    } catch (err) {
      return {
        ok: false,
        message: err instanceof Error ? err.message : 'Gửi tin nhắn thất bại',
      };
    }
  }

  /**
   * Không phải sự kiện nhận từ client — BookingsService gọi trực tiếp mỗi khi trạng
   * thái đơn đặt thay đổi.
   */
  emitBookingStatusChanged(
    recipientUserId: string,
    payload: { booking_id: string; status: string; studio_name: string },
  ) {
    this.realtime.emitToUsers(
      [recipientUserId],
      'booking_status_changed',
      payload,
    );
  }
}
