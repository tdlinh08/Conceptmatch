// MÚI GIỜ: backend tính giờ mở cửa, phụ thu giờ tối, giờ trong thông báo theo giờ MÁY CHỦ.
// Máy Windows ở VN thì đúng sẵn, nhưng chạy trong Docker (mặc định UTC) sẽ lệch 7 tiếng
// -> cố định giờ Việt Nam. Phải đặt TRƯỚC khi tạo bất kỳ Date nào.
process.env.TZ = process.env.APP_TZ || 'Asia/Ho_Chi_Minh'; // đổi múi giờ bằng biến APP_TZ

import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Phục vụ file người dùng tải lên (ảnh đại diện...) tại http://<máy chủ>:3000/uploads/...
  // Không nằm dưới /api/v1 vì setGlobalPrefix chỉ áp dụng cho route của controller.
  app.useStaticAssets(join(process.cwd(), 'uploads'), { prefix: '/uploads' });

  app.setGlobalPrefix('api/v1');
  app.enableCors();
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // tự động loại bỏ field lạ không khai báo trong DTO
      forbidNonWhitelisted: true, // báo lỗi 400 nếu client gửi field lạ
      transform: true, // tự convert kiểu dữ liệu (vd: query string "1" -> number 1)
    }),
  );

  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');
  console.log(
    `ConceptMatch backend đang chạy tại http://localhost:${port}/api/v1`,
  );
}
bootstrap();
