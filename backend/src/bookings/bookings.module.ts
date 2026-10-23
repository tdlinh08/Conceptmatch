import { Module } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { BookingsController } from './bookings.controller';
import { ConversationsModule } from '../conversations/conversations.module';

@Module({
  imports: [ConversationsModule],
  controllers: [BookingsController],
  providers: [BookingsService],
})
export class BookingsModule {}
