import { Injectable, Logger } from '@nestjs/common';
import type { Server } from 'socket.io';

/**
 * Cầu nối để các service khác (thông báo, tin nhắn, đơn đặt) đẩy sự kiện real-time
 * qua Socket.IO mà không phải phụ thuộc trực tiếp vào ChatGateway (tránh vòng lặp module).
 *
 * ChatGateway gắn đối tượng Server vào đây khi khởi động (afterInit). Mỗi người dùng
 * khi kết nối socket được cho vào phòng `user:<id>` -> gửi tới phòng đó là tới mọi
 * thiết bị đang mở của người đó.
 */
@Injectable()
export class RealtimeService {
  private server?: Server;
  private readonly logger = new Logger(RealtimeService.name);

  attach(server: Server) {
    this.server = server;
  }

  /** Gửi sự kiện tới một hoặc nhiều người dùng. Không ném lỗi: real-time hỏng không được làm hỏng thao tác chính. */
  emitToUsers(userIds: string[], event: string, payload: unknown) {
    if (!this.server || userIds.length === 0) return;
    try {
      const rooms = [...new Set(userIds)].map((id) => `user:${id}`);
      this.server.to(rooms).emit(event, payload);
    } catch (err) {
      this.logger.warn(`Không gửi được sự kiện ${event}: ${String(err)}`);
    }
  }
}
