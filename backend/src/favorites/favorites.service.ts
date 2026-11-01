import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { STUDIO_SUMMARY_SELECT, toStudioSummary } from '../studios/studio-summary';

@Injectable()
export class FavoritesService {
  constructor(private prisma: PrismaService) {}

  async addFavorite(userId: string, studioId: string) {
    const studio = await this.prisma.studio.findUnique({ where: { id: studioId } });
    if (!studio) {
      throw new NotFoundException('Studio không tồn tại');
    }

    // Idempotent: bấm nút tim 2 lần liên tiếp (vd: do mạng chậm, người dùng
    // bấm lại) không báo lỗi trùng — chỉ đơn giản trả về thành công, giúp
    // phía Flutter không cần xử lý riêng lỗi 409 cho nút yêu thích.
    const existing = await this.prisma.favorite.findUnique({
      where: { user_id_studio_id: { user_id: userId, studio_id: studioId } },
    });
    if (existing) {
      return { message: 'Đã có trong danh sách yêu thích' };
    }

    await this.prisma.favorite.create({
      data: { user_id: userId, studio_id: studioId },
    });
    return { message: 'Đã thêm vào yêu thích' };
  }

  async removeFavorite(userId: string, studioId: string) {
    // deleteMany không báo lỗi nếu không tìm thấy bản ghi -> idempotent
    // tương tự addFavorite, cùng lý do.
    await this.prisma.favorite.deleteMany({
      where: { user_id: userId, studio_id: studioId },
    });
    return { message: 'Đã bỏ yêu thích' };
  }

  async findAll(userId: string) {
    const favorites = await this.prisma.favorite.findMany({
      where: { user_id: userId },
      orderBy: { created_at: 'desc' },
      include: { studio: { select: STUDIO_SUMMARY_SELECT } },
    });

    // Cùng dạng dữ liệu với thẻ studio ở Home (min_price = gói rẻ nhất)
    return favorites.map((f) => toStudioSummary(f.studio));
  }
}