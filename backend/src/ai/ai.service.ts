import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { AxiosError } from 'axios';
import FormData from 'form-data';

const AI_SERVICE_TIMEOUT_MS = 15000; // Theo API Contract: quá thời gian này coi như "AI Service không phản hồi"

@Injectable()
export class AiService {
  constructor(
    private http: HttpService,
    private config: ConfigService,
  ) {}

  async visualSearch(file: Express.Multer.File, topK: number) {
    const form = new FormData();
    form.append('image', file.buffer, {
      filename: file.originalname,
      contentType: file.mimetype,
    });
    form.append('top_k', String(topK));

    const aiServiceUrl = this.config.get<string>('AI_SERVICE_URL') ?? 'http://localhost:8000';

    try {
      const response = await firstValueFrom(
        this.http.post(`${aiServiceUrl}/search`, form, {
          headers: form.getHeaders(),
          timeout: AI_SERVICE_TIMEOUT_MS,
        }),
      );
      return response.data;
    } catch (err) {
      const error = err as AxiosError;

      // Đúng theo API Contract: 503 khi AI Service timeout hoặc không phản hồi.
      // KHÔNG tự động fallback sang text search ở tầng backend — để phía
      // Frontend/Mobile tự bắt lỗi 503 này và chuyển sang gọi GET /studios
      // với từ khoá do người dùng nhập, vì visual search vốn không có sẵn
      // "từ khoá" nào để tự fallback thay người dùng.
      if (
        error.code === 'ECONNABORTED' ||
        error.code === 'ECONNREFUSED' ||
        !error.response
      ) {
        throw new ServiceUnavailableException(
          'AI Service không phản hồi, vui lòng thử lại hoặc tìm kiếm bằng từ khoá',
        );
      }
      throw error;
    }
  }
}
