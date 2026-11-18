# Backend NestJS cho ConceptMatch.
# Build:  docker compose build backend      (chạy từ thư mục gốc dự án)
FROM node:20-bookworm-slim

WORKDIR /app

# openssl: Prisma cần để kết nối Postgres; tzdata: giờ Việt Nam cho lịch đặt
RUN apt-get update && apt-get install -y --no-install-recommends openssl tzdata \
    && rm -rf /var/lib/apt/lists/*
ENV TZ=Asia/Ho_Chi_Minh

# Cài thư viện trước (tận dụng cache khi chỉ sửa code)
COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
RUN npx prisma generate

COPY . .
RUN npm run build

EXPOSE 3000

# Áp dụng migration (tạo bảng, extension pgvector) rồi chạy server
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main"]
