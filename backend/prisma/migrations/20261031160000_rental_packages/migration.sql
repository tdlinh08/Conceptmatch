-- Mô hình GÓI THUÊ theo concept (31/10/2026)
-- 1) Studio có giờ mở cửa riêng + phụ thu giờ tối / cuối tuần (%)
-- 2) Bảng rental_packages: gói thuê của từng set
-- 3) Booking lưu gói, số người, chi tiết giá
-- 4) CHUYỂN DỮ LIỆU từ bảng giá 4 ô cũ (pricing_rules) sang mô hình mới, rồi xoá bảng cũ

-- AlterTable
ALTER TABLE "studios" ADD COLUMN     "close_time" VARCHAR(5) NOT NULL DEFAULT '22:00',
ADD COLUMN     "evening_start_time" VARCHAR(5) NOT NULL DEFAULT '18:00',
ADD COLUMN     "evening_surcharge_pct" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "open_time" VARCHAR(5) NOT NULL DEFAULT '08:00',
ADD COLUMN     "weekend_surcharge_pct" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "rental_packages" (
    "id" TEXT NOT NULL,
    "set_id" TEXT NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "duration_minutes" INTEGER NOT NULL,
    "price" DECIMAL(12,2) NOT NULL,
    "included_people" INTEGER NOT NULL DEFAULT 1,
    "extra_person_fee" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "max_people" INTEGER NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rental_packages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "rental_packages_set_id_idx" ON "rental_packages"("set_id");

-- AddForeignKey
ALTER TABLE "rental_packages" ADD CONSTRAINT "rental_packages_set_id_fkey" FOREIGN KEY ("set_id") REFERENCES "studio_sets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AlterTable
ALTER TABLE "bookings" ADD COLUMN     "base_amount" DECIMAL(12,2),
ADD COLUMN     "extra_people_amount" DECIMAL(12,2),
ADD COLUMN     "num_people" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "package_id" TEXT,
ADD COLUMN     "package_name" VARCHAR(100),
ADD COLUMN     "surcharge_amount" DECIMAL(12,2);

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_package_id_fkey" FOREIGN KEY ("package_id") REFERENCES "rental_packages"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ---------------------------------------------------------------------------
-- Chuyển dữ liệu (viết tay, Prisma không tự sinh phần này)
-- Giá gốc = giá giờ thường ngày thường. Giờ vàng / cuối tuần -> % phụ thu so với giá gốc.
-- ---------------------------------------------------------------------------
WITH p AS (
    SELECT studio_id,
           MAX(price_per_hour) FILTER (WHERE slot_type = 'normal' AND day_type = 'weekday') AS base,
           MAX(price_per_hour) FILTER (WHERE slot_type = 'golden' AND day_type = 'weekday') AS golden,
           MAX(price_per_hour) FILTER (WHERE slot_type = 'normal' AND day_type = 'weekend') AS weekend
    FROM "pricing_rules"
    GROUP BY studio_id
)
UPDATE "studios" s
SET "evening_surcharge_pct" = GREATEST(0, ROUND((p.golden / p.base - 1) * 100))::INTEGER,
    "weekend_surcharge_pct" = GREATEST(0, ROUND((p.weekend / p.base - 1) * 100))::INTEGER
FROM p
WHERE p.studio_id = s.id AND p.base > 0
  AND p.golden IS NOT NULL AND p.weekend IS NOT NULL;

-- Mỗi set cũ có 1 gói "Thuê theo giờ" (60 phút), sức chứa = capacity của set.
INSERT INTO "rental_packages" ("id", "set_id", "name", "description", "duration_minutes", "price",
                               "included_people", "extra_person_fee", "max_people", "updated_at")
SELECT gen_random_uuid()::TEXT, ss.id, 'Thuê theo giờ', 'Tạo tự động từ bảng giá theo giờ cũ', 60, p.price_per_hour,
       ss.capacity, 0, ss.capacity, CURRENT_TIMESTAMP
FROM "studio_sets" ss
JOIN "pricing_rules" p
  ON p.studio_id = ss.studio_id AND p.slot_type = 'normal' AND p.day_type = 'weekday';

-- DropForeignKey
ALTER TABLE "pricing_rules" DROP CONSTRAINT "pricing_rules_studio_id_fkey";

-- DropTable
DROP TABLE "pricing_rules";

-- DropEnum
DROP TYPE "DayType";

-- DropEnum
DROP TYPE "SlotType";
