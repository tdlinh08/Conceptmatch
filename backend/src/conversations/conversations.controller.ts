import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('conversations')
export class ConversationsController {
  constructor(private conversationsService: ConversationsService) {}

  /** Khách bắt đầu (hoặc mở lại) cuộc trò chuyện với một studio. */
  @Roles('user')
  @Post()
  create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateConversationDto,
  ) {
    return this.conversationsService.findOrCreate(userId, dto.studio_id);
  }

  @Roles('user', 'studio_owner')
  @Get()
  findAll(@CurrentUser('id') userId: string) {
    return this.conversationsService.findAllForUser(userId);
  }

  @Roles('user', 'studio_owner')
  @Get('unread-count')
  unreadCount(@CurrentUser('id') userId: string) {
    return this.conversationsService.unreadTotal(userId);
  }

  @Roles('user', 'studio_owner')
  @Get(':id/messages')
  findMessages(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.conversationsService.findMessages(
      id,
      userId,
      Number(page) || 1,
      Number(limit) || 30,
    );
  }

  /** Gửi tin qua REST (app dùng cách này; socket "send_message" vẫn được hỗ trợ). */
  @Roles('user', 'studio_owner')
  @Post(':id/messages')
  send(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.conversationsService.sendMessage(id, userId, dto.content);
  }

  @Roles('user', 'studio_owner')
  @Patch(':id/read')
  @HttpCode(200)
  markRead(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.conversationsService.markRead(id, userId);
  }
}
