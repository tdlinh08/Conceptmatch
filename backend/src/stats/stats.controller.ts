import { Controller, Get, Query } from '@nestjs/common';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { QueryStatsDto } from './dto/query-stats.dto';
import { StatsService } from './stats.service';

@Controller('stats')
export class StatsController {
  constructor(private stats: StatsService) {}

  /** Thống kê toàn sàn cho admin: biểu đồ đơn / doanh thu / người dùng mới, top 10 studio... */
  @Roles('admin')
  @Get('admin')
  admin(@Query() q: QueryStatsDto) {
    return this.stats.forAdmin(q.range);
  }

  /** Báo cáo doanh thu của chủ studio (mọi studio của tôi hoặc 1 studio). */
  @Roles('studio_owner')
  @Get('owner')
  owner(@CurrentUser('id') ownerId: string, @Query() q: QueryStatsDto) {
    return this.stats.forOwner(ownerId, q.range, q.studio_id);
  }
}
