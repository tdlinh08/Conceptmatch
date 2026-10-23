import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { GoogleAuthDto } from './dto/google-auth.dto';
import { Public } from './decorators/public.decorator';
import { CurrentUser } from './decorators/current-user.decorator';
import type { AuthenticatedUser } from './decorators/current-user.decorator';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('google')
  loginWithGoogle(@Body() dto: GoogleAuthDto) {
    return this.authService.loginWithGoogle(dto.id_token);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshTokens(dto.refresh_token);
  }

  // Không đánh dấu @Public() -> bắt buộc phải có access token hợp lệ
  // mới biết logout tài khoản nào (JwtAuthGuard global sẽ tự chặn).
  @HttpCode(HttpStatus.OK)
  @Post('logout')
  logout(@CurrentUser('id') userId: string) {
    return this.authService.logout(userId);
  }

  // Bổ sung so với API Contract gốc — cần thiết để client (Flutter) khôi
  // phục lại thông tin user khi mở lại app từ access token đã lưu sẵn,
  // không cần đăng nhập lại. Trả về đúng payload JwtStrategy.validate() đã
  // xác thực, không truy vấn DB thêm lần nữa (đã có sẵn trong request.user).
  @Get('me')
  me(@CurrentUser() user: AuthenticatedUser) {
    return user;
  }
}

