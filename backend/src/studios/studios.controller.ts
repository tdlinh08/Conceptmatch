import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { StudiosService } from './studios.service';
import { CreateStudioDto } from './dto/create-studio.dto';
import { UpdateStudioDto } from './dto/update-studio.dto';
import { QueryStudiosDto } from './dto/query-studios.dto';
import { CreateStudioSetDto } from './dto/create-studio-set.dto';
import { AvailabilityQueryDto } from './dto/availability-query.dto';
import { UpsertPricingRuleDto } from './dto/upsert-pricing-rule.dto';
import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('studios')
export class StudiosController {
  constructor(private studiosService: StudiosService) {}

  @Public()
  @Get()
  findAll(@Query() query: QueryStudiosDto) {
    return this.studiosService.findAll(query);
  }

  // 3 route "chữ" dưới đây BẮT BUỘC khai báo TRƯỚC @Get(':id') — nếu không,
  // NestJS sẽ hiểu "featured"/"style-tags"/"for-you" là giá trị của tham số
  // :id (khớp route theo thứ tự khai báo), gây lỗi 400 "id không phải UUID
  // hợp lệ" thay vì chạy đúng logic mong muốn.

  @Public()
  @Get('featured')
  findFeatured(@Query('limit') limit?: number) {
    return this.studiosService.findFeatured(Number(limit) || 10);
  }

  @Public()
  @Get('style-tags')
  findStyleTags() {
    return this.studiosService.findStyleTags();
  }

  @Roles('user')
  @Get('for-you')
  findForYou(
    @CurrentUser('id') userId: string,
    @Query('limit') limit?: number,
  ) {
    return this.studiosService.findForYou(userId, Number(limit) || 10);
  }

  @Public()
  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.studiosService.findOne(id);
  }

  @Roles('studio_owner')
  @Post()
  create(@CurrentUser('id') ownerId: string, @Body() dto: CreateStudioDto) {
    return this.studiosService.create(ownerId, dto);
  }

  @Roles('studio_owner')
  @Put(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: UpdateStudioDto,
  ) {
    return this.studiosService.update(id, ownerId, dto);
  }

  @Public()
  @Get(':id/sets')
  findSets(@Param('id', ParseUUIDPipe) id: string) {
    return this.studiosService.findSets(id);
  }

  @Roles('user')
  @Post(':id/view')
  recordView(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.studiosService.recordView(id, userId);
  }

  @Roles('studio_owner')
  @Post(':id/sets')
  createSet(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: CreateStudioSetDto,
  ) {
    return this.studiosService.createSet(id, ownerId, dto);
  }

  @Public()
  @Get(':id/availability')
  getAvailability(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: AvailabilityQueryDto,
  ) {
    return this.studiosService.getAvailability(id, query);
  }

  @Public()
  @Get(':id/reviews')
  findReviews(
    @Param('id', ParseUUIDPipe) id: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.studiosService.findReviews(id, Number(page) || 1, Number(limit) || 10);
  }

  // --- Pricing Rules: KHÔNG có trong API Contract gốc, tự bổ sung vì SRS (S-03)
  // và bảng CSDL Pricing_Rules đã có nhưng thiếu endpoint. Ghi chú trong báo cáo.

  @Public()
  @Get(':id/pricing-rules')
  findPricingRules(@Param('id', ParseUUIDPipe) id: string) {
    return this.studiosService.findPricingRules(id);
  }

  @Roles('studio_owner')
  @Post(':id/pricing-rules')
  upsertPricingRule(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: UpsertPricingRuleDto,
  ) {
    return this.studiosService.upsertPricingRule(id, ownerId, dto);
  }

  @Roles('studio_owner')
  @Delete(':id/pricing-rules/:ruleId')
  deletePricingRule(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('ruleId', ParseUUIDPipe) ruleId: string,
    @CurrentUser('id') ownerId: string,
  ) {
    return this.studiosService.deletePricingRule(id, ownerId, ruleId);
  }
}
