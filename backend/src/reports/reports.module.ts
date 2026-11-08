import { Module } from '@nestjs/common';
import { AdminModule } from '../admin/admin.module';
import { AdminReportsController, ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';

@Module({
  imports: [AdminModule], // dùng AdminService.takeDownStudio khi xử lý báo cáo studio
  controllers: [ReportsController, AdminReportsController],
  providers: [ReportsService],
})
export class ReportsModule {}
