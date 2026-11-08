import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { AiModule } from '../ai/ai.module';
import { StudiosModule } from '../studios/studios.module';

@Module({
  imports: [AiModule, StudiosModule], // AiService: tạo vector khi duyệt; StudiosService: chi tiết studio
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService], // ReportsModule: gỡ studio khi xử lý báo cáo
})
export class AdminModule {}
