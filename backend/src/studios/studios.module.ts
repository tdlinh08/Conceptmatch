import { Module } from '@nestjs/common';
import { StudiosService } from './studios.service';
import { StudiosController } from './studios.controller';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [AiModule], // tạo/sửa set khi studio đang hoạt động -> encode ảnh cho AI
  controllers: [StudiosController],
  providers: [StudiosService],
})
export class StudiosModule {}
