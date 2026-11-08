import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import {
  CreateReportDto,
  DismissReportDto,
  HideReviewDto,
  QueryReportsDto,
  ResolveReportDto,
} from './dto/report.dto';
import { ReportsService } from './reports.service';

/** Khách / chủ studio gửi báo cáo vi phạm. */
@Controller('reports')
export class ReportsController {
  constructor(private reports: ReportsService) {}

  @Roles('user', 'studio_owner')
  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateReportDto) {
    return this.reports.create(userId, dto);
  }
}

/** Admin xử lý báo cáo + kiểm duyệt đánh giá. */
@Roles('admin')
@Controller('admin')
export class AdminReportsController {
  constructor(private reports: ReportsService) {}

  @Get('reports')
  findAll(@Query() q: QueryReportsDto) {
    return this.reports.findAll(q);
  }

  @Patch('reports/:id/resolve')
  resolve(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: ResolveReportDto,
  ) {
    return this.reports.resolve(id, adminId, dto);
  }

  @Patch('reports/:id/dismiss')
  dismiss(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: DismissReportDto,
  ) {
    return this.reports.dismiss(id, adminId, dto.note);
  }

  @Patch('reviews/:id/hide')
  hide(@Param('id', ParseUUIDPipe) id: string, @CurrentUser('id') adminId: string, @Body() dto: HideReviewDto) {
    return this.reports.hideReview(id, adminId, dto.reason);
  }

  @Patch('reviews/:id/unhide')
  unhide(@Param('id', ParseUUIDPipe) id: string, @CurrentUser('id') adminId: string) {
    return this.reports.unhideReview(id, adminId);
  }
}
