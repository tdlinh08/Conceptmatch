-- Album ảnh của từng bối cảnh (set): khách xem trước khi đặt, tối đa 10 ảnh / set (kiểm tra ở backend).
CREATE TABLE "set_images" (
    "id" TEXT NOT NULL,
    "set_id" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "set_images_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "set_images_set_id_idx" ON "set_images"("set_id");

ALTER TABLE "set_images" ADD CONSTRAINT "set_images_set_id_fkey" FOREIGN KEY ("set_id") REFERENCES "studio_sets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
