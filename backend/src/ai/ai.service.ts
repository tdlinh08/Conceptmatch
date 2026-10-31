import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { AxiosError } from 'axios';
import FormData from 'form-data';
import { promises as fs } from 'fs';
import { PrismaService } from '../prisma/prisma.service';
import { localPathOf } from '../media/media.util';

const AI_SERVICE_TIMEOUT_MS = 15000; // Theo API Contract: quá thời gian này coi như "AI Service không phản hồi"

@Injectable()
export class AiService {
  constructor(
    private http: HttpService,
    private config: ConfigService,
    private prisma: PrismaService,
  ) {}

  private get aiServiceUrl(): string {
    return this.config.get<string>('AI_SERVICE_URL') ?? 'http://localhost:8000';
  }

  /**
   * Mã hoá ảnh đại diện của các set thành CLIP embedding (lưu vào studio_sets.clip_embedding)
   * rồi yêu cầu AI Service dựng lại FAISS index. Dùng chung cho:
   *  - Admin duyệt studio (index toàn bộ set của studio)
   *  - Chủ studio thêm/sửa set khi studio đã hoạt động
   * Không ném lỗi: ảnh nào lỗi chỉ ghi cảnh báo, để không làm hỏng thao tác chính.
   */
  async indexSets(setIds: string[]): Promise<string[]> {
    const warnings: string[] = [];
    if (setIds.length === 0) return warnings;

    const sets = await this.prisma.studioSet.findMany({
      where: { id: { in: setIds }, is_active: true },
    });

    for (const set of sets) {
      try {
        const imageBuffer = await this.loadImage(set.avatar_url);

        const form = new FormData();
        form.append('image', imageBuffer, { filename: 'avatar.jpg' });
        const encodeResponse = await firstValueFrom(
          this.http.post(`${this.aiServiceUrl}/encode`, form, {
            headers: form.getHeaders(),
            timeout: AI_SERVICE_TIMEOUT_MS,
          }),
        );

        const embedding: number[] = encodeResponse.data.embedding;
        const vectorLiteral = `[${embedding.join(',')}]`;
        // $executeRaw bắt buộc: clip_embedding là Unsupported("vector(512)") trong Prisma.
        await this.prisma.$executeRaw`
          UPDATE studio_sets
          SET clip_embedding = ${vectorLiteral}::vector
          WHERE id::text = ${set.id}
        `;
      } catch (err) {
        warnings.push(
          `Không thể encode ảnh cho set "${set.name}" (${set.id}): ${
            err instanceof Error ? err.message : 'lỗi không xác định'
          }`,
        );
      }
    }

    const reindexWarning = await this.reindex();
    if (reindexWarning) warnings.push(reindexWarning);
    return warnings;
  }

  /** Index toàn bộ set đang hoạt động của một studio (dùng khi Admin duyệt). */
  async indexStudio(studioId: string): Promise<string[]> {
    const sets = await this.prisma.studioSet.findMany({
      where: { studio_id: studioId, is_active: true },
      select: { id: true },
    });
    return this.indexSets(sets.map((s) => s.id));
  }

  /** Yêu cầu AI Service dựng lại FAISS index từ DB. Trả về câu cảnh báo nếu thất bại. */
  async reindex(): Promise<string | null> {
    try {
      await firstValueFrom(
        this.http.post(`${this.aiServiceUrl}/reindex`, {}, { timeout: AI_SERVICE_TIMEOUT_MS }),
      );
      return null;
    } catch {
      return 'Không thể gọi /reindex ngay — FAISS index sẽ tự cập nhật ở lần khởi động AI Service tiếp theo';
    }
  }

  /** Ảnh tải lên hệ thống ("/uploads/...") đọc thẳng từ đĩa; link ngoài thì tải về. */
  private async loadImage(url: string): Promise<Buffer> {
    const localPath = localPathOf(url);
    if (localPath) return fs.readFile(localPath);

    const response = await firstValueFrom(
      this.http.get(url, { responseType: 'arraybuffer', timeout: 10000 }),
    );
    return Buffer.from(response.data);
  }

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
