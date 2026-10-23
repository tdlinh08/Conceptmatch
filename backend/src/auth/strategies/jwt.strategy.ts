import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';

interface JwtPayload {
  sub: string;
  email: string;
  role: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('JWT_ACCESS_SECRET'),
    });
  }

  // Được gọi tự động sau khi verify chữ ký + hạn token thành công.
  // Giá trị return sẽ được gắn vào request.user (dùng trong @CurrentUser()).
  async validate(payload: JwtPayload) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });

    // Trả về null/undefined -> Passport tự động ném 401 Unauthorized
    if (!user || user.status === 'locked') {
      return null;
    }

    return {
      id: user.id,
      email: user.email,
      role: user.role,
      full_name: user.full_name,
    };
  }
}
