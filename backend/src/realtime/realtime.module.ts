import { Global, Module } from '@nestjs/common';
import { RealtimeService } from './realtime.service';

// @Global: NotificationsService, ConversationsService… dùng chung mà không cần import module
@Global()
@Module({
  providers: [RealtimeService],
  exports: [RealtimeService],
})
export class RealtimeModule {}
