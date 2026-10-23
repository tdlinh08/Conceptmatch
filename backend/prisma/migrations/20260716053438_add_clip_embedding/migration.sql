CREATE EXTENSION IF NOT EXISTS vector;
-- AlterTable
ALTER TABLE "studio_sets" ADD COLUMN "clip_embedding" vector(512);

-- CreateIndex
CREATE INDEX "audit_logs_admin_id_idx" ON "audit_logs"("admin_id");

-- CreateIndex
CREATE INDEX "bookings_user_id_idx" ON "bookings"("user_id");

-- CreateIndex
CREATE INDEX "bookings_studio_id_idx" ON "bookings"("studio_id");

-- CreateIndex
CREATE INDEX "bookings_set_id_start_time_end_time_idx" ON "bookings"("set_id", "start_time", "end_time");

-- CreateIndex
CREATE INDEX "conversations_user_id_idx" ON "conversations"("user_id");

-- CreateIndex
CREATE INDEX "conversations_studio_id_idx" ON "conversations"("studio_id");

-- CreateIndex
CREATE INDEX "messages_conversation_id_idx" ON "messages"("conversation_id");

-- CreateIndex
CREATE INDEX "notifications_recipient_id_idx" ON "notifications"("recipient_id");

-- CreateIndex
CREATE INDEX "pricing_rules_studio_id_idx" ON "pricing_rules"("studio_id");

-- CreateIndex
CREATE INDEX "reviews_studio_id_idx" ON "reviews"("studio_id");

-- CreateIndex
CREATE INDEX "studio_images_studio_id_idx" ON "studio_images"("studio_id");

-- CreateIndex
CREATE INDEX "studio_sets_studio_id_idx" ON "studio_sets"("studio_id");

-- CreateIndex
CREATE INDEX "studios_owner_id_idx" ON "studios"("owner_id");

-- CreateIndex
CREATE INDEX "studios_district_idx" ON "studios"("district");

-- CreateIndex
CREATE INDEX "studios_status_idx" ON "studios"("status");
