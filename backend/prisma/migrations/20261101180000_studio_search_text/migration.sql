-- TÌM KIẾM KHÔNG DẤU (01/11/2026): cột search_text = tên + quận + địa chỉ + tên set + concept,
-- đã bỏ dấu + chữ thường. Ứng dụng cập nhật cột này khi sửa studio / set (src/common/search-text.ts).

-- AlterTable
ALTER TABLE "studios" ADD COLUMN     "search_text" TEXT;

-- Điền cho studio đã có: lower() rồi translate() từng chữ có dấu -> không dấu
-- (bảng chữ sinh tự động, khớp với normalizeSearch() phía TypeScript).
UPDATE "studios" s
SET "search_text" = regexp_replace(
  translate(
    lower(concat_ws(' ', s.name, s.district, s.address, (
      SELECT string_agg(concat_ws(' ', ss.name, ss.style_tag), ' ')
      FROM "studio_sets" ss
      WHERE ss.studio_id = s.id AND ss.is_active
    ))),
    'àáâãäåèéêëìíîïòóôõöùúûüýÿāăąďđēĕėęěĩīĭįōŏőũūŭůűųŷơưǎǐǒǔǖǘǚǜǟǡǫǭǻȁȃȅȇȉȋȍȏȕȗȧȩȫȭȯȱȳḁḋḍḏḑḓḕḗḙḛḝḭḯṍṏṑṓṳṵṷṹṻẏẙạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ',
    'aaaaaaeeeeiiiiooooouuuuyyaaaddeeeeeiiiiooouuuuuuyouaiouuuuuaaooaaaeeiioouuaeooooyadddddeeeeeiioooouuuuuyyaaaaaaaaaaaaeeeeeeeeiioooooooooooouuuuuuuyyyy'
  ),
  '\s+', ' ', 'g'
);
