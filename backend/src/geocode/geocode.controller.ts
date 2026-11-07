import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { Roles } from '../auth/decorators/roles.decorator';
import { GeocodeService } from './geocode.service';

/** Tìm địa chỉ để ghim vị trí studio — chỉ chủ studio dùng (tránh lạm dụng dịch vụ miễn phí). */
@Controller('geocode')
export class GeocodeController {
  constructor(private geocode: GeocodeService) {}

  @Roles('studio_owner')
  @Get()
  search(@Query('q') q?: string) {
    const text = (q ?? '').trim();
    if (text.length < 3) throw new BadRequestException('Nhập ít nhất 3 ký tự để tìm địa chỉ');
    if (text.length > 200) throw new BadRequestException('Địa chỉ quá dài');
    return this.geocode.search(text);
  }
}
