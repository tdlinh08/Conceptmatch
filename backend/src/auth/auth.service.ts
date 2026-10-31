import {
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '7d';
const BCRYPT_COST = 12;

@Injectable()
export class AuthService {
  private googleClient: OAuth2Client;

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
  ) {
    this.googleClient = new OAuth2Client(
      this.config.getOrThrow<string>('GOOGLE_CLIENT_ID'),
    );
  }

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) {
      throw new ConflictException('Email đã tồn tại');
    }

    const password_hash = await bcrypt.hash(dto.password, BCRYPT_COST);

    const user = await this.prisma.user.create({
      data: {
        full_name: dto.full_name,
        email: dto.email,
        password_hash,
        role: dto.role ?? 'user',
      },
    });

    return {
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      role: user.role,
    };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });

    // Không phân biệt "email không tồn tại" và "sai mật khẩu" trong response
    // để tránh lộ thông tin email nào đã đăng ký (user enumeration).
    if (!user || !user.password_hash) {
      throw new UnauthorizedException('Sai email hoặc mật khẩu');
    }

    if (user.status === 'locked') {
      throw new ForbiddenException('Tài khoản bị khoá');
    }

    const passwordMatches = await bcrypt.compare(
      dto.password,
      user.password_hash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException('Sai email hoặc mật khẩu');
    }

    return this.issueTokens(user.id, user.email, user.role);
  }

  /**
   * Luồng ID token: Flutter app dùng Google Sign-In SDK lấy id_token trực tiếp
   * từ Google trên thiết bị, gửi id_token đó lên đây để backend xác minh chữ ký
   * và audience (client_id) — KHÔNG dùng luồng redirect authorization code.
   */
  async loginWithGoogle(idToken: string) {
    let payload;
    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken,
        audience: this.config.getOrThrow<string>('GOOGLE_CLIENT_ID'),
      });
      payload = ticket.getPayload();
    } catch {
      throw new UnauthorizedException('Google token không hợp lệ');
    }

    if (!payload?.email || !payload.sub) {
      throw new UnauthorizedException('Google token không hợp lệ');
    }

    let user = await this.prisma.user.findUnique({
      where: { google_id: payload.sub },
    });

    if (!user) {
      // Chưa từng đăng nhập Google trước đây — kiểm tra xem email này đã
      // đăng ký bằng password chưa, nếu có thì gộp (link) vào tài khoản đó
      // thay vì tạo tài khoản trùng email.
      const existingByEmail = await this.prisma.user.findUnique({
        where: { email: payload.email },
      });

      if (existingByEmail) {
        user = await this.prisma.user.update({
          where: { id: existingByEmail.id },
          data: {
            google_id: payload.sub,
            avatar_url: payload.picture ?? existingByEmail.avatar_url,
          },
        });
      } else {
        user = await this.prisma.user.create({
          data: {
            full_name: payload.name ?? payload.email.split('@')[0],
            email: payload.email,
            google_id: payload.sub,
            avatar_url: payload.picture,
          },
        });
      }
    }

    if (user.status === 'locked') {
      throw new ForbiddenException('Tài khoản bị khoá');
    }

    const tokens = await this.issueTokens(user.id, user.email, user.role);
    return {
      ...tokens,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        role: user.role,
        avatar_url: user.avatar_url,
      },
    };
  }

  async refreshTokens(refreshToken: string) {
    let payload: { sub: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken, {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Refresh token hết hạn hoặc không hợp lệ');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });

    if (!user || !user.refresh_token_hash) {
      throw new UnauthorizedException('Refresh token không hợp lệ');
    }

    const matches = await bcrypt.compare(refreshToken, user.refresh_token_hash);
    if (!matches) {
      throw new UnauthorizedException('Refresh token không hợp lệ');
    }

    const access_token = await this.signAccessToken(
      user.id,
      user.email,
      user.role,
    );

    return { access_token };
  }

  async logout(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { refresh_token_hash: null },
    });
    return { message: 'Đăng xuất thành công' };
  }

  private async issueTokens(userId: string, email: string, role: string) {
    const access_token = await this.signAccessToken(userId, email, role);
    const refresh_token = await this.jwt.signAsync(
      { sub: userId, email },
      {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
        expiresIn: REFRESH_TOKEN_TTL,
      },
    );

    // Không bao giờ lưu refresh token gốc trong DB — chỉ lưu bcrypt hash,
    // giống hệt cách lưu password. Nếu DB bị lộ, kẻ tấn công vẫn không tự
    // giả mạo được refresh token.
    const refresh_token_hash = await bcrypt.hash(refresh_token, BCRYPT_COST);
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { refresh_token_hash },
    });

    return {
      access_token,
      refresh_token,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        role: user.role,
        avatar_url: user.avatar_url,
        has_password: user.password_hash !== null,
      },
    };
  }

  private signAccessToken(userId: string, email: string, role: string) {
    return this.jwt.signAsync(
      { sub: userId, email, role },
      {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        expiresIn: ACCESS_TOKEN_TTL,
      },
    );
  }
}
