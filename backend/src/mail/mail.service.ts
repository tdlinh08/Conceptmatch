import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';

/**
 * Gửi email qua SMTP (ví dụ Gmail + Mật khẩu ứng dụng).
 *
 * Cấu hình trong .env:
 *   SMTP_HOST=smtp.gmail.com   SMTP_PORT=465
 *   SMTP_USER=<gmail của bạn>  SMTP_PASS=<mật khẩu ứng dụng 16 ký tự>
 *   MAIL_FROM="Hanoi Photobooth <gmail của bạn>"
 *
 * Chưa cấu hình SMTP (đang phát triển): không gửi thật mà in nội dung email ra
 * log của backend để vẫn thử được luồng quên mật khẩu.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly transporter: Transporter | null;
  private readonly from: string;

  constructor(config: ConfigService) {
    const host = config.get<string>('SMTP_HOST');
    const user = config.get<string>('SMTP_USER');
    const pass = config.get<string>('SMTP_PASS');
    const port = Number(config.get<string>('SMTP_PORT') ?? 465);
    this.from =
      config.get<string>('MAIL_FROM') ??
      `Hanoi Photobooth <${user ?? 'no-reply@hanoiphotobooth.local'}>`;
    this.transporter =
      host && user && pass
        ? nodemailer.createTransport({
            host,
            port,
            secure: port === 465,
            auth: { user, pass },
          })
        : null;
    if (!this.transporter) {
      this.logger.warn(
        'Chưa cấu hình SMTP_HOST/SMTP_USER/SMTP_PASS -> email sẽ được in ra log thay vì gửi thật.',
      );
    }
  }

  get isConfigured(): boolean {
    return this.transporter !== null;
  }

  /** Gửi email; ném lỗi nếu máy chủ SMTP từ chối. */
  async send(
    to: string,
    subject: string,
    text: string,
    html?: string,
  ): Promise<void> {
    if (!this.transporter) {
      this.logger.warn(
        `[EMAIL CHƯA GỬI THẬT] Tới: ${to} | ${subject}\n${text}`,
      );
      return;
    }
    await this.transporter.sendMail({
      from: this.from,
      to,
      subject,
      text,
      html,
    });
  }
}
