-- Vector CLIP cho từng ảnh album của bối cảnh (AI tìm theo nhiều góc chụp)
ALTER TABLE "set_images" ADD COLUMN "clip_embedding" vector(512);
