import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';

@Module({
  imports: [HttpModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
