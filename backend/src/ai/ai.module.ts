import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';

@Module({
  imports: [HttpModule],
  controllers: [AiController],
  providers: [AiService],
  exports: [AiService], // Admin và Studios dùng để tạo vector cho ảnh set
})
export class AiModule {}
