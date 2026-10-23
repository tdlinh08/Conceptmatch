import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

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
  console.log(`ConceptMatch backend đang chạy tại http://localhost:${port}/api/v1`);
}
bootstrap();
