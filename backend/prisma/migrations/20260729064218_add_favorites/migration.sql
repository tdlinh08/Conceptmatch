-- CreateTable
CREATE TABLE "favorites" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "studio_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "favorites_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "favorites_user_id_idx" ON "favorites"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "favorites_user_id_studio_id_key" ON "favorites"("user_id", "studio_id");

-- AddForeignKey
ALTER TABLE "favorites" ADD CONSTRAINT "favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "favorites" ADD CONSTRAINT "favorites_studio_id_fkey" FOREIGN KEY ("studio_id") REFERENCES "studios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
