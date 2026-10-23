import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('conversations')
export class ConversationsController {
  constructor(private conversationsService: ConversationsService) {}

  // Bổ sung so với API Contract gốc — cần 1 cách để bắt đầu conversation mới,
  // contract chỉ có GET danh sách + GET tin nhắn, thiếu endpoint tạo.
  @Roles('user')
  @Post()
  create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateConversationDto,
  ) {
    return this.conversationsService.findOrCreate(userId, dto.studio_id);
  }

  @Get()
  findAll(@CurrentUser('id') userId: string) {
    return this.conversationsService.findAllForUser(userId);
  }

  @Get(':id/messages')
  findMessages(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.conversationsService.findMessages(
      id,
      userId,
      Number(page) || 1,
      Number(limit) || 20,
    );
  }
}
