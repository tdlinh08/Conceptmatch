/**
 * Chuẩn hoá chữ tiếng Việt để tìm kiếm KHÔNG phân biệt dấu, hoa/thường:
 *   "Studio Hoa Nắng, Hai Bà Trưng" -> "studio hoa nang, hai ba trung"
 * Dùng cho cả dữ liệu (cột studios.search_text) và từ khoá người dùng gõ.
 * Postgres không có sẵn tìm bỏ dấu (cần extension unaccent) -> tự chuẩn hoá ở ứng dụng,
 * chạy được trên mọi bản Postgres / Docker image.
 */
export function normalizeSearch(text: string): string {
  return text
    .normalize('NFD') // tách chữ và dấu: "ắ" -> "a" + dấu mũ + dấu sắc
    .replace(/[̀-ͯ]/g, '') // bỏ các dấu
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/** Tách từ khoá thành các từ (đã chuẩn hoá) — studio phải chứa TẤT CẢ các từ. */
export function searchWords(keyword: string): string[] {
  return normalizeSearch(keyword)
    .split(' ')
    .filter((w) => w.length > 0)
    .slice(0, 6); // giới hạn để câu truy vấn không quá dài
}
