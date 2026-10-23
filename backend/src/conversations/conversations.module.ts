import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConversationsService } from './conversations.service';
import { ConversationsController } from './conversations.controller';
import { ChatGateway } from './chat.gateway';

@Module({
  imports: [JwtModule.register({})],
  controllers: [ConversationsController],
  providers: [ConversationsService, ChatGateway],
  exports: [ChatGateway],
})
export class ConversationsModule {}
