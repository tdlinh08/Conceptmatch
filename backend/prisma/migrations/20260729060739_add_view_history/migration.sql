-- CreateTable
CREATE TABLE "view_history" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "studio_id" TEXT NOT NULL,
    "viewed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "view_history_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "view_history_user_id_viewed_at_idx" ON "view_history"("user_id", "viewed_at");

-- CreateIndex
CREATE INDEX "view_history_studio_id_idx" ON "view_history"("studio_id");

-- AddForeignKey
ALTER TABLE "view_history" ADD CONSTRAINT "view_history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "view_history" ADD CONSTRAINT "view_history_studio_id_fkey" FOREIGN KEY ("studio_id") REFERENCES "studios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
