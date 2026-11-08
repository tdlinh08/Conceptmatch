-- Báo cáo vi phạm + ẩn đánh giá (07/11/2026)
ALTER TYPE "NotificationType" ADD VALUE 'report_handled';

CREATE TYPE "ReportTargetType" AS ENUM ('studio', 'review');
CREATE TYPE "ReportStatus" AS ENUM ('pending', 'resolved', 'dismissed');

ALTER TABLE "reviews" ADD COLUMN "is_hidden" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "reviews" ADD COLUMN "hidden_reason" TEXT;

CREATE TABLE "reports" (
    "id" TEXT NOT NULL,
    "reporter_id" TEXT NOT NULL,
    "target_type" "ReportTargetType" NOT NULL,
    "target_id" TEXT NOT NULL,
    "reason" VARCHAR(100) NOT NULL,
    "detail" TEXT,
    "status" "ReportStatus" NOT NULL DEFAULT 'pending',
    "admin_note" TEXT,
    "handled_by" TEXT,
    "handled_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reports_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "reports_status_idx" ON "reports"("status");
CREATE INDEX "reports_target_type_target_id_idx" ON "reports"("target_type", "target_id");

ALTER TABLE "reports" ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "reports" ADD CONSTRAINT "reports_handled_by_fkey" FOREIGN KEY ("handled_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
