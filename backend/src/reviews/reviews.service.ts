import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateReviewDto } from './dto/create-review.dto';

@Injectable()
export class ReviewsService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, dto: CreateReviewDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: dto.booking_id },
    });
    if (!booking) {
      throw new NotFoundException('Booking không tồn tại');
    }
    if (booking.user_id !== userId) {
      throw new ForbiddenException('Booking này không phải của bạn');
    }
    if (booking.status !== 'completed') {
      throw new ForbiddenException(
        'Booking chưa hoàn thành, không thể đánh giá',
      );
    }

    // Ràng buộc @@unique trên booking_id trong schema đã chặn ở tầng DB,
    // nhưng kiểm tra trước ở đây để trả lỗi rõ ràng hơn (409 thay vì lỗi DB thô).
    const existing = await this.prisma.review.findUnique({
      where: { booking_id: dto.booking_id },
    });
    if (existing) {
      throw new ConflictException('Booking này đã được đánh giá');
    }

    return this.prisma.$transaction(async (tx) => {
      const review = await tx.review.create({
        data: {
          booking_id: dto.booking_id,
          user_id: userId,
          studio_id: booking.studio_id,
          stars: dto.stars,
          comment: dto.comment,
        },
      });

      // Tính lại avg_rating + review_count từ toàn bộ review của studio.
      // Cách này (aggregate lại từ đầu) chậm hơn 1 chút so với cập nhật tăng dần
      // (incremental), nhưng luôn chính xác tuyệt đối, không bao giờ bị lệch số
      // do lỗi cộng dồn — chấp nhận được vì tần suất review thấp hơn nhiều so
      // với booking.
      const agg = await tx.review.aggregate({
        where: { studio_id: booking.studio_id },
        _avg: { stars: true },
        _count: { stars: true },
      });

      await tx.studio.update({
        where: { id: booking.studio_id },
        data: {
          avg_rating: agg._avg.stars ?? 0,
          review_count: agg._count.stars,
        },
      });

      return review;
    });
  }
}
