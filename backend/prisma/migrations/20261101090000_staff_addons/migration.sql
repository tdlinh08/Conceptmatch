-- NHÂN SỰ + DỊCH VỤ THÊM (01/11/2026): thợ ảnh, thợ trang điểm

-- CreateEnum
CREATE TYPE "StaffRole" AS ENUM ('photographer', 'makeup');

-- CreateEnum
CREATE TYPE "AddonUnit" AS ENUM ('per_booking', 'per_hour', 'per_person');

-- AlterTable
ALTER TABLE "bookings" ADD COLUMN     "addons_amount" DECIMAL(12,2);

-- CreateTable
CREATE TABLE "staff_members" (
    "id" TEXT NOT NULL,
    "studio_id" TEXT NOT NULL,
    "full_name" VARCHAR(100) NOT NULL,
    "role" "StaffRole" NOT NULL,
    "phone" VARCHAR(20),
    "avatar_url" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "staff_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "addon_services" (
    "id" TEXT NOT NULL,
    "studio_id" TEXT NOT NULL,
    "role" "StaffRole" NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "price" DECIMAL(12,2) NOT NULL,
    "unit" "AddonUnit" NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "addon_services_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "booking_addons" (
    "id" TEXT NOT NULL,
    "booking_id" TEXT NOT NULL,
    "addon_id" TEXT,
    "name" VARCHAR(100) NOT NULL,
    "role" "StaffRole" NOT NULL,
    "unit" "AddonUnit" NOT NULL,
    "unit_price" DECIMAL(12,2) NOT NULL,
    "quantity" DECIMAL(6,2) NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "staff_id" TEXT,

    CONSTRAINT "booking_addons_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "staff_members_studio_id_idx" ON "staff_members"("studio_id");

-- CreateIndex
CREATE INDEX "addon_services_studio_id_idx" ON "addon_services"("studio_id");

-- CreateIndex
CREATE INDEX "booking_addons_booking_id_idx" ON "booking_addons"("booking_id");

-- CreateIndex
CREATE INDEX "booking_addons_staff_id_idx" ON "booking_addons"("staff_id");

-- AddForeignKey
ALTER TABLE "staff_members" ADD CONSTRAINT "staff_members_studio_id_fkey" FOREIGN KEY ("studio_id") REFERENCES "studios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "addon_services" ADD CONSTRAINT "addon_services_studio_id_fkey" FOREIGN KEY ("studio_id") REFERENCES "studios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_addons" ADD CONSTRAINT "booking_addons_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_addons" ADD CONSTRAINT "booking_addons_addon_id_fkey" FOREIGN KEY ("addon_id") REFERENCES "addon_services"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_addons" ADD CONSTRAINT "booking_addons_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff_members"("id") ON DELETE SET NULL ON UPDATE CASCADE;
