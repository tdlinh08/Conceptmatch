import { Prisma } from '@prisma/client';

/**
 * Dạng dữ liệu "thẻ studio" dùng chung cho danh sách, nổi bật, gợi ý, đã lưu,
 * studio của tôi — khai báo MỘT lần để mọi API trả cùng một dạng.
 */
export const STUDIO_SUMMARY_SELECT = {
  id: true,
  name: true,
  district: true,
  avg_rating: true,
  images: { where: { is_cover: true }, take: 1, select: { url: true } },
  // Gói rẻ nhất của từng set đang hoạt động -> thẻ hiện "Từ ...đ"
  sets: {
    where: { is_active: true },
    select: {
      packages: {
        where: { is_active: true },
        orderBy: { price: 'asc' },
        take: 1,
        select: { price: true, duration_minutes: true },
      },
    },
  },
} satisfies Prisma.StudioSelect;

export type StudioSummaryRow = Prisma.StudioGetPayload<{
  select: typeof STUDIO_SUMMARY_SELECT;
}>;

export function toStudioSummary(s: StudioSummaryRow) {
  const cheapest = s.sets
    .flatMap((set) => set.packages)
    .reduce<{ price: number; duration_minutes: number } | null>((min, p) => {
      const price = Number(p.price);
      return min === null || price < min.price
        ? { price, duration_minutes: p.duration_minutes }
        : min;
    }, null);

  return {
    id: s.id,
    name: s.name,
    district: s.district,
    avg_rating: s.avg_rating,
    cover_image: s.images[0]?.url ?? null,
    // Giá gói rẻ nhất (null nếu studio chưa có gói nào) + thời lượng gói đó,
    // để app hiện "Từ 650.000đ / 1 giờ" thay vì ngầm hiểu là theo giờ.
    min_price: cheapest?.price ?? null,
    min_price_minutes: cheapest?.duration_minutes ?? null,
  };
}
