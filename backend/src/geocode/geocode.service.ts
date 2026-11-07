import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';

export interface GeocodeResult {
  name: string; // dòng chính, vd "Phố Huế"
  address: string; // địa chỉ đầy đủ
  latitude: number;
  longitude: number;
}

/**
 * Tìm địa chỉ -> toạ độ bằng Nominatim (OpenStreetMap), miễn phí, không cần key.
 * Gọi qua backend (không gọi thẳng từ app) để:
 *  - gửi User-Agent định danh ứng dụng (bắt buộc theo chính sách của Nominatim);
 *  - giới hạn tối đa 1 yêu cầu / giây cho cả hệ thống (chính sách của Nominatim);
 *  - lưu đệm kết quả, cùng một từ khoá không phải hỏi lại.
 */
@Injectable()
export class GeocodeService {
  private readonly logger = new Logger(GeocodeService.name);
  private readonly cache = new Map<string, GeocodeResult[]>();
  private queue: Promise<unknown> = Promise.resolve();
  private lastCall = 0;

  // Đổi được bằng biến môi trường (vd trỏ sang máy chủ Nominatim riêng)
  private readonly baseUrl = process.env.GEOCODE_URL ?? 'https://nominatim.openstreetmap.org';

  async search(query: string): Promise<GeocodeResult[]> {
    const q = query.trim().replace(/\s+/g, ' ');
    const key = q.toLowerCase();
    const hit = this.cache.get(key);
    if (hit) return hit;

    // Xếp hàng: các yêu cầu cách nhau ít nhất 1 giây
    const run = this.queue.then(async () => {
      const wait = this.lastCall + 1000 - Date.now();
      if (wait > 0) await new Promise((r) => setTimeout(r, wait));
      this.lastCall = Date.now();
      return this.request(q);
    });
    this.queue = run.catch(() => undefined);
    const results = await run;

    if (this.cache.size > 500) this.cache.clear(); // tránh phình bộ nhớ
    this.cache.set(key, results);
    return results;
  }

  private async request(q: string): Promise<GeocodeResult[]> {
    const params = new URLSearchParams({
      q,
      format: 'jsonv2',
      addressdetails: '0',
      limit: '6',
      countrycodes: 'vn',
      'accept-language': 'vi',
      // Ưu tiên (không bắt buộc) khu vực Hà Nội
      viewbox: '105.30,21.40,106.05,20.55',
    });
    let res: Response;
    try {
      res = await fetch(`${this.baseUrl}/search?${params}`, {
        headers: { 'User-Agent': 'ConceptMatch-DoAn/1.0 (do an tot nghiep, DH Kien truc Ha Noi)' },
        signal: AbortSignal.timeout(8000),
      });
    } catch (err) {
      this.logger.warn(`Không gọi được dịch vụ tìm địa chỉ: ${String(err)}`);
      throw new ServiceUnavailableException(
        'Không kết nối được dịch vụ tìm địa chỉ. Hãy kéo bản đồ để ghim thủ công.',
      );
    }
    if (!res.ok) {
      this.logger.warn(`Dịch vụ tìm địa chỉ trả lỗi ${res.status}`);
      throw new ServiceUnavailableException(
        'Dịch vụ tìm địa chỉ đang bận, thử lại sau ít phút hoặc kéo bản đồ để ghim.',
      );
    }
    const rows = (await res.json()) as {
      name?: string;
      display_name: string;
      lat: string;
      lon: string;
    }[];
    return rows.map((r) => ({
      name: r.name || r.display_name.split(',')[0],
      address: r.display_name,
      latitude: Number(r.lat),
      longitude: Number(r.lon),
    }));
  }
}
