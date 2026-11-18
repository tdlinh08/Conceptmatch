import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import type { PrismaService } from '../prisma/prisma.service';
import type { RealtimeService } from '../realtime/realtime.service';

/** Kiểm thử đơn vị phần gửi tin: kiểm tra nội dung, quyền và sự kiện real-time. */
describe('ConversationsService.sendMessage', () => {
  const conversation = {
    id: 'c1',
    user_id: 'khach',
    studio_id: 's1',
    studio: { owner_id: 'chu' },
  };
  const saved = {
    id: 'm1',
    conversation_id: 'c1',
    content: 'Xin chào',
    sender_id: 'khach',
    is_read: false,
    sent_at: new Date('2026-11-18T09:00:00Z'),
  };

  function setup() {
    const prisma = {
      conversation: {
        findUnique: jest.fn().mockResolvedValue(conversation),
        update: jest.fn().mockReturnValue('update'),
      },
      message: { create: jest.fn().mockReturnValue('create') },
      $transaction: jest.fn().mockResolvedValue([saved, {}]),
    };
    const realtime = { emitToUsers: jest.fn() };
    const service = new ConversationsService(
      prisma as unknown as PrismaService,
      realtime as unknown as RealtimeService,
    );
    return { prisma, realtime, service };
  }

  it('từ chối tin rỗng hoặc chỉ có khoảng trắng', async () => {
    const { service, prisma } = setup();
    await expect(
      service.sendMessage('c1', 'khach', '   '),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('từ chối tin dài quá 2000 ký tự', async () => {
    const { service } = setup();
    await expect(
      service.sendMessage('c1', 'khach', 'a'.repeat(2001)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('người ngoài cuộc trò chuyện không gửi được', async () => {
    const { service } = setup();
    await expect(
      service.sendMessage('c1', 'nguoi-la', 'hi'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('lưu tin đã cắt khoảng trắng và gửi real-time tới cả hai phía', async () => {
    const { service, prisma, realtime } = setup();
    const result = await service.sendMessage('c1', 'khach', '  Xin chào  ');
    expect(prisma.message.create).toHaveBeenCalledWith(
      expect.objectContaining({
        // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment -- matcher của Jest có kiểu any
        data: expect.objectContaining({
          content: 'Xin chào',
          sender_id: 'khach',
        }),
      }),
    );
    expect(realtime.emitToUsers).toHaveBeenCalledWith(
      ['khach', 'chu'],
      'message_received',
      saved,
    );
    expect(result).toBe(saved);
  });
});
