import { BadRequestException, Injectable, ServiceUnavailableException } from '@nestjs/common';
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
      select: { id: true, name: true, avatar_url: true },
    });

    for (const set of sets) {
      // 1) Ảnh đại diện: luôn mã hoá lại (có thể vừa đổi ảnh)
      try {
        const vector = await this.encodeUrl(set.avatar_url);
        await this.prisma.$executeRaw`
          UPDATE studio_sets SET clip_embedding = ${vector}::vector WHERE id::text = ${set.id}
        `;
      } catch (err) {
        warnings.push(`Không thể encode ảnh đại diện của set "${set.name}": ${this.errText(err)}`);
      }

      // 2) Ảnh album chưa có vector: mã hoá thêm -> AI so khớp được với nhiều góc chụp của bối cảnh
      const album = await this.prisma.$queryRaw<{ id: string; url: string }[]>`
        SELECT id, url FROM set_images WHERE set_id = ${set.id} AND clip_embedding IS NULL
      `;
      for (const img of album) {
        try {
          const vector = await this.encodeUrl(img.url);
          await this.prisma.$executeRaw`
            UPDATE set_images SET clip_embedding = ${vector}::vector WHERE id = ${img.id}
          `;
        } catch (err) {
          warnings.push(`Không thể encode 1 ảnh album của set "${set.name}": ${this.errText(err)}`);
        }
      }
    }

    const reindexWarning = await this.reindex();
    if (reindexWarning) warnings.push(reindexWarning);
    return warnings;
  }

  /** Gửi 1 ảnh sang AI Service /encode, trả về vector dạng chuỗi "[...]" để ghi vào cột vector. */
  private async encodeUrl(url: string): Promise<string> {
    const imageBuffer = await this.loadImage(url);
    const form = new FormData();
    form.append('image', imageBuffer, { filename: 'image.jpg', contentType: this.mimeOf(url) });
    const res = await firstValueFrom(
      this.http.post(`${this.aiServiceUrl}/encode`, form, {
        headers: form.getHeaders(),
        timeout: AI_SERVICE_TIMEOUT_MS,
      }),
    );
    const embedding: number[] = res.data.embedding;
    return `[${embedding.join(',')}]`;
  }

  private mimeOf(url: string) {
    const u = url.toLowerCase();
    if (u.endsWith('.png')) return 'image/png';
    if (u.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  private errText(err: unknown) {
    return err instanceof Error ? err.message : 'lỗi không xác định';
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

  /**
   * Tìm bối cảnh giống ảnh người dùng gửi. AI Service trả về (set, độ tương đồng, ảnh khớp nhất);
   * backend bổ sung thông tin để app hiển thị ngay (quận, điểm, giá từ, concept) và LỌC BỎ
   * set / studio không còn hoạt động (phòng khi chỉ mục FAISS chưa kịp cập nhật).
   */
  async visualSearch(file: Express.Multer.File, topK: number) {
    const form = new FormData();
    form.append('image', file.buffer, {
      filename: file.originalname,
      contentType: file.mimetype,
    });
    form.append('top_k', String(topK));

    const started = Date.now();
    let raw: AiSearchItem[];
    try {
      const response = await firstValueFrom(
        this.http.post(`${this.aiServiceUrl}/search`, form, {
          headers: form.getHeaders(),
          timeout: AI_SERVICE_TIMEOUT_MS,
        }),
      );
      raw = (response.data?.results ?? []) as AiSearchItem[];
    } catch (err) {
      const error = err as AxiosError;
      // Theo API Contract: 503 khi AI Service timeout / không phản hồi. App tự gợi ý
      // chuyển sang tìm bằng từ khoá (ảnh không có "từ khoá" nào để backend tự fallback).
      if (error.code === 'ECONNABORTED' || error.code === 'ECONNREFUSED' || !error.response) {
        throw new ServiceUnavailableException(
          'AI Service không phản hồi, vui lòng thử lại hoặc tìm kiếm bằng từ khoá',
        );
      }
      if (error.response.status === 400 || error.response.status === 413) {
        const detail = (error.response.data as { detail?: string })?.detail;
        throw new BadRequestException(detail ?? 'Ảnh không hợp lệ');
      }
      throw new ServiceUnavailableException('AI Service gặp lỗi khi xử lý ảnh, vui lòng thử lại');
    }

    const sets = await this.prisma.studioSet.findMany({
      where: {
        id: { in: raw.map((r) => r.set_id) },
        is_active: true,
        studio: { status: 'active' },
      },
      select: {
        id: true,
        name: true,
        style_tag: true,
        capacity: true,
        avatar_url: true,
        studio: { select: { id: true, name: true, district: true, avg_rating: true, review_count: true } },
        packages: {
          where: { is_active: true },
          orderBy: { price: 'asc' },
          take: 1,
          select: { price: true, duration_minutes: true },
        },
      },
    });
    const byId = new Map(sets.map((s) => [s.id, s]));

    const results = raw
      .filter((r) => byId.has(r.set_id))
      .map((r) => {
        const s = byId.get(r.set_id)!;
        return {
          set_id: s.id,
          set_name: s.name,
          style_tag: s.style_tag,
          capacity: s.capacity,
          avatar_url: s.avatar_url,
          matched_image_url: r.matched_image_url ?? s.avatar_url, // ảnh của bối cảnh giống nhất
          studio_id: s.studio.id,
          studio_name: s.studio.name,
          district: s.studio.district,
          avg_rating: Number(s.studio.avg_rating),
          review_count: s.studio.review_count,
          min_price: s.packages[0] ? Number(s.packages[0].price) : null,
          min_price_minutes: s.packages[0]?.duration_minutes ?? null,
          similarity: Math.round(r.similarity_score * 1000) / 1000, // cosine (-1..1), thường 0,5–0,95
        };
      });

    return { results, took_ms: Date.now() - started };
  }
}

/** 1 kết quả thô từ AI Service. */
interface AiSearchItem {
  set_id: string;
  similarity_score: number;
  matched_image_url?: string;
}
