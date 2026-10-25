import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

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
      include: {
        studio: {
          select: {
            id: true,
            name: true,
            district: true,
            avg_rating: true,
            images: { where: { is_cover: true }, take: 1, select: { url: true } },
            // Giá rẻ nhất -> thẻ studio ở tab "Đã lưu" hiện "Từ ...đ / giờ"
            // giống hệt thẻ ở Home (cùng dạng dữ liệu với StudiosService.toSummary).
            pricing_rules: {
              orderBy: { price_per_hour: 'asc' },
              take: 1,
              select: { price_per_hour: true },
            },
          },
        },
      },
    });

    return favorites.map((f) => ({
      id: f.studio.id,
      name: f.studio.name,
      district: f.studio.district,
      avg_rating: f.studio.avg_rating,
      cover_image: f.studio.images[0]?.url ?? null,
      min_price: f.studio.pricing_rules[0]
        ? Number(f.studio.pricing_rules[0].price_per_hour)
        : null,
    }));
  }
}