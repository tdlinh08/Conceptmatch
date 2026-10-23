import { Controller, Delete, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { FavoritesService } from './favorites.service';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

// Không dùng @Controller('favorites') làm prefix chung, vì 2 route thêm/xoá
// hợp lý hơn khi nằm dưới /studios/:id/favorite (theo đúng resource studio),
// còn route danh sách lại là /favorites (theo đúng resource "của tôi") —
// khai path đầy đủ thủ công cho từng route thay vì dùng 1 prefix cố định.
@Controller()
export class FavoritesController {
  constructor(private favoritesService: FavoritesService) {}

  @Roles('user')
  @Post('studios/:id/favorite')
  addFavorite(
    @Param('id', ParseUUIDPipe) studioId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.favoritesService.addFavorite(userId, studioId);
  }

  @Roles('user')
  @Delete('studios/:id/favorite')
  removeFavorite(
    @Param('id', ParseUUIDPipe) studioId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.favoritesService.removeFavorite(userId, studioId);
  }

  @Roles('user')
  @Get('favorites')
  findAll(@CurrentUser('id') userId: string) {
    return this.favoritesService.findAll(userId);
  }
}
