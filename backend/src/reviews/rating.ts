import { Prisma } from '@prisma/client';

/**
 * Tính lại điểm trung bình + số đánh giá của 1 studio từ các đánh giá ĐANG HIỆN
 * (đánh giá bị admin ẩn không được tính). Gọi sau khi thêm / ẩn / hiện đánh giá.
 */
export async function recomputeStudioRating(tx: Prisma.TransactionClient, studioId: string) {
  const agg = await tx.review.aggregate({
    where: { studio_id: studioId, is_hidden: false },
    _avg: { stars: true },
    _count: { stars: true },
  });
  await tx.studio.update({
    where: { id: studioId },
    data: { avg_rating: agg._avg.stars ?? 0, review_count: agg._count.stars },
  });
}
