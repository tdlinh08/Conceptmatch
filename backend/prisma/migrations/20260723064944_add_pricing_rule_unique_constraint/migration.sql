/*
  Warnings:

  - A unique constraint covering the columns `[studio_id,slot_type,day_type]` on the table `pricing_rules` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateIndex
CREATE UNIQUE INDEX "pricing_rules_studio_id_slot_type_day_type_key" ON "pricing_rules"("studio_id", "slot_type", "day_type");
