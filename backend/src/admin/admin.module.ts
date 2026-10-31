import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [AiModule], // dùng AiService.indexStudio() khi duyệt studio
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
