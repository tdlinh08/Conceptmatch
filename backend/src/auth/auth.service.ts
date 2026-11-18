import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Logger,
  ServiceUnavailableException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
import { randomInt } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '7d';
const BCRYPT_COST = 12;

// Quên mật khẩu
const RESET_CODE_TTL_MIN = 15; // mã có hiệu lực 15 phút
const RESET_MAX_ATTEMPTS = 5; // nhập sai 5 lần thì mã bị huỷ
const RESET_RESEND_SECONDS = 60; // 60 giây mới gửi lại mã mới
const FORGOT_MESSAGE =
  'Nếu email đã đăng ký, mã xác nhận gồm 6 chữ số đã được gửi tới email. Mã có hiệu lực 15 phút.';
const INVALID_CODE = 'Mã xác nhận không đúng hoặc đã hết hạn';

@Injectable()
export class AuthService {
  private googleClient: OAuth2Client;
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
    private mail: MailService,
  ) {
    this.googleClient = new OAuth2Client(
      this.config.getOrThrow<string>('GOOGLE_CLIENT_ID'),
    );
  }

  async register(dto: RegisterDto) {
    // So khớp không phân biệt hoa/thường để không tạo 2 tài khoản "A@x.com" và "a@x.com"
    const existing = await this.prisma.user.findFirst({
      where: { email: { equals: dto.email, mode: 'insensitive' } },
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
    // Không phân biệt hoa/thường: tài khoản cũ có thể đã lưu email có chữ hoa
    const user = await this.prisma.user.findFirst({
      where: { email: { equals: dto.email, mode: 'insensitive' } },
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
      throw new UnauthorizedException(
        'Refresh token hết hạn hoặc không hợp lệ',
      );
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

  /**
   * Quên mật khẩu – bước 1: tạo mã 6 số, lưu bản băm, gửi qua email.
   * Luôn trả cùng một thông báo (không cho biết email có tồn tại hay không).
   */
  async forgotPassword(email: string) {
    const user = await this.prisma.user.findFirst({
      where: { email: { equals: email, mode: 'insensitive' } },
    });
    if (!user || user.status === 'locked') return { message: FORGOT_MESSAGE };

    // Chống gửi dồn dập: mã gần nhất mới tạo dưới 60 giây thì không gửi thêm
    const last = await this.prisma.passwordReset.findFirst({
      where: { user_id: user.id },
      orderBy: { created_at: 'desc' },
    });
    if (
      last &&
      Date.now() - last.created_at.getTime() < RESET_RESEND_SECONDS * 1000
    ) {
      return { message: FORGOT_MESSAGE };
    }

    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    const code_hash = await bcrypt.hash(code, 10);
    const expires_at = new Date(Date.now() + RESET_CODE_TTL_MIN * 60_000);

    // Mã mới thay thế mọi mã cũ chưa dùng
    await this.prisma.$transaction([
      this.prisma.passwordReset.updateMany({
        where: { user_id: user.id, used_at: null },
        data: { used_at: new Date() },
      }),
      this.prisma.passwordReset.create({
        data: { user_id: user.id, code_hash, expires_at },
      }),
    ]);

    const text =
      `Xin chào ${user.full_name},\n\n` +
      `Mã đặt lại mật khẩu Hanoi Photobooth của bạn là: ${code}\n` +
      `Mã có hiệu lực ${RESET_CODE_TTL_MIN} phút. Không chia sẻ mã này cho người khác.\n\n` +
      'Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này.';
    const html =
      `<p>Xin chào ${escapeHtml(user.full_name)},</p>` +
      `<p>Mã đặt lại mật khẩu Hanoi Photobooth của bạn là:</p>` +
      `<p style="font-size:28px;font-weight:bold;letter-spacing:6px">${code}</p>` +
      `<p>Mã có hiệu lực ${RESET_CODE_TTL_MIN} phút. Không chia sẻ mã này cho người khác.</p>` +
      '<p>Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này.</p>';
    try {
      await this.mail.send(
        user.email,
        'Mã đặt lại mật khẩu Hanoi Photobooth',
        text,
        html,
      );
    } catch (err) {
      this.logger.error(
        `Không gửi được email đặt lại mật khẩu: ${err instanceof Error ? err.message : err}`,
      );
      throw new ServiceUnavailableException(
        'Không gửi được email lúc này, vui lòng thử lại sau',
      );
    }
    return { message: FORGOT_MESSAGE };
  }

  /**
   * Quên mật khẩu – bước 2: kiểm tra mã, đặt mật khẩu mới,
   * thu hồi phiên đăng nhập trên mọi thiết bị.
   */
  async resetPassword(email: string, code: string, newPassword: string) {
    const user = await this.prisma.user.findFirst({
      where: { email: { equals: email, mode: 'insensitive' } },
    });
    if (!user || user.status === 'locked')
      throw new BadRequestException(INVALID_CODE);

    const reset = await this.prisma.passwordReset.findFirst({
      where: {
        user_id: user.id,
        used_at: null,
        expires_at: { gt: new Date() },
      },
      orderBy: { created_at: 'desc' },
    });
    if (!reset) throw new BadRequestException(INVALID_CODE);

    if (!(await bcrypt.compare(code, reset.code_hash))) {
      const attempts = reset.attempts + 1;
      await this.prisma.passwordReset.update({
        where: { id: reset.id },
        data: {
          attempts,
          ...(attempts >= RESET_MAX_ATTEMPTS ? { used_at: new Date() } : {}),
        },
      });
      const left = RESET_MAX_ATTEMPTS - attempts;
      throw new BadRequestException(
        left > 0
          ? `Mã xác nhận không đúng (còn ${left} lần thử)`
          : 'Nhập sai quá 5 lần, vui lòng yêu cầu mã mới',
      );
    }

    const password_hash = await bcrypt.hash(newPassword, BCRYPT_COST);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: { password_hash, refresh_token_hash: null }, // đăng xuất mọi thiết bị
      }),
      this.prisma.passwordReset.update({
        where: { id: reset.id },
        data: { used_at: new Date() },
      }),
    ]);
    return {
      message:
        'Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới.',
    };
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

function escapeHtml(s: string): string {
  return s.replace(
    /[&<>"']/g,
    (c) =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[
        c
      ]!,
  );
}
