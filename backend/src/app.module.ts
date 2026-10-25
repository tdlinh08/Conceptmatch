import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { StudiosModule } from './studios/studios.module';
import { BookingsModule } from './bookings/bookings.module';
import { ReviewsModule } from './reviews/reviews.module';
import { AiModule } from './ai/ai.module';
import { AdminModule } from './admin/admin.module';
import { ConversationsModule } from './conversations/conversations.module';
import { FavoritesModule } from './favorites/favorites.module';
import { UsersModule } from './users/users.module';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { RolesGuard } from './auth/guards/roles.guard';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    StudiosModule,
    BookingsModule,
    ReviewsModule,
    AiModule,
    AdminModule,
    ConversationsModule,
    FavoritesModule,
    UsersModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    // Áp dụng cho MỌI route trong toàn app. Route nào muốn public thì gắn
    // @Public() (xem auth/decorators/public.decorator.ts), ví dụ các route
    // /auth/register, /auth/login, và sau này là GET /studios (xem công khai).
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}
