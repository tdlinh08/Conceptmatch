/**
 * NHẬP DỮ LIỆU STUDIO THẬT TỪ EXCEL + THƯ MỤC ẢNH
 * ------------------------------------------------------------------
 *   npm run seed:studios                      -> nhập tất cả studio "nhap_vao_app = Có"
 *   npm run seed:studios -- --kiem-tra        -> chỉ kiểm tra file + ảnh, KHÔNG ghi gì
 *   npm run seed:studios -- --chi S01,S02     -> chỉ nhập vài studio
 *   npm run seed:studios -- --khong-ai        -> nhập nhưng bỏ qua bước AI mã hoá ảnh
 *   npm run seed:studios -- --chi-ai          -> không nhập lại, chỉ cho AI mã hoá ảnh còn thiếu
 *   (thêm --file <xlsx> / --anh <thư mục> nếu để file ở chỗ khác)
 *
 * Chạy trong thư mục backend/. Đọc DATABASE_URL, AI_SERVICE_URL, SEED_OWNER_PASSWORD trong .env.
 *
 * Mỗi bối cảnh (ma_set) có 1 thư mục ảnh seed_data/du_lieu_anh/<ma_set>/ (~20 ảnh):
 *   - 16 ảnh ĐƯA VÀO HỆ THỐNG: 1 ảnh đại diện + tối đa 15 ảnh album -> AI mã hoá cả 16
 *   - 4 ảnh KIỂM THỬ: không đưa vào app, ghi vào seed_data/test_manifest.json để đánh giá AI
 *   Có thư mục con "test/" -> ảnh trong đó là ảnh kiểm thử. Không có -> tự lấy ảnh thứ 5, 10, 15, 20
 *   (sắp theo tên). Ảnh tên bắt đầu "dai_dien" là ảnh đại diện, không có thì lấy ảnh đầu tiên.
 *
 * Chạy lại an toàn: studio đã nhập (cùng chủ + cùng tên) mà CHƯA có đơn đặt -> xoá và nhập lại;
 * đã có đơn đặt -> bỏ qua (không làm mất lịch sử đặt lịch).
 */
import 'dotenv/config';
import { promises as fs, existsSync } from 'fs';
import { extname, join, relative, resolve } from 'path';
import axios from 'axios';
import * as bcrypt from 'bcrypt';
import ExcelJS from 'exceljs';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { AddonUnit, Prisma, StaffRole } from '@prisma/client';
import { PrismaService } from '../src/prisma/prisma.service';
import { AiService } from '../src/ai/ai.service';
import { UPLOADS_ROOT } from '../src/media/media.util';
import { normalizeSearch } from '../src/common/search-text';
import { MAX_SET_IMAGES } from '../src/studios/studios.service';

// ============================================================= tham số dòng lệnh
const argv = process.argv.slice(2);
const flag = (name: string) => argv.includes(name);
const option = (name: string) => {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : undefined;
};
const SEED_DIR = resolve(process.cwd(), '..', 'seed_data');
const EXCEL_FILE = resolve(option('--file') ?? join(SEED_DIR, 'du_lieu_studio_v3.xlsx'));
const IMAGE_DIR = resolve(option('--anh') ?? join(SEED_DIR, 'du_lieu_anh'));
const MANIFEST_FILE = join(SEED_DIR, 'test_manifest.json');
const ONLY = option('--chi')?.split(',').map((s) => s.trim().toUpperCase()).filter(Boolean);
const CHECK_ONLY = flag('--kiem-tra');
const SKIP_AI = flag('--khong-ai');
const AI_ONLY = flag('--chi-ai');

const DISTRICTS = [
  'Ba Đình', 'Hoàn Kiếm', 'Đống Đa', 'Hai Bà Trưng', 'Cầu Giấy', 'Tây Hồ', 'Thanh Xuân',
  'Hoàng Mai', 'Long Biên', 'Nam Từ Liêm', 'Bắc Từ Liêm', 'Hà Đông',
];
const IMAGE_EXT = ['.jpg', '.jpeg', '.png', '.webp'];
const TEST_PER_SET_AUTO = 5; // tự chia: cứ 5 ảnh lấy 1 ảnh làm ảnh kiểm thử (20 ảnh -> 4 ảnh)
const BIG_IMAGE_BYTES = 3 * 1024 * 1024;
const BCRYPT_COST = 12; // giống AuthService
const ROLE: Record<string, StaffRole> = { 'thợ ảnh': 'photographer', 'thợ trang điểm': 'makeup' };
const UNIT: Record<string, AddonUnit> = {
  'theo lượt': 'per_booking', 'theo giờ': 'per_hour', 'theo người': 'per_person',
};

// ============================================================= đọc Excel
type Row = { _sheet: string; _row: number; [col: string]: string | number | null };

/** Ô Excel -> chữ / số. Xử lý cả ô giờ (Excel tự đổi "08:00" thành kiểu thời gian), link, công thức. */
function cellValue(v: ExcelJS.CellValue): string | number | null {
  if (v === null || v === undefined) return null;
  if (v instanceof Date) {
    return `${String(v.getUTCHours()).padStart(2, '0')}:${String(v.getUTCMinutes()).padStart(2, '0')}`;
  }
  if (typeof v === 'number') return v;
  if (typeof v === 'boolean') return v ? 'Có' : 'Không';
  if (typeof v === 'string') return v.trim() === '' ? null : v.trim();
  if (typeof v === 'object') {
    if ('richText' in v) return cellValue(v.richText.map((t) => t.text).join(''));
    if ('result' in v) return cellValue(v.result as ExcelJS.CellValue);
    if ('text' in v) return cellValue(v.text as string);
  }
  return String(v);
}

async function readWorkbook(file: string) {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(file);
  const read = (name: string): Row[] => {
    const ws = wb.getWorksheet(name);
    if (!ws) throw new Error(`File Excel thiếu sheet "${name}"`);
    const headers: string[] = [];
    ws.getRow(1).eachCell((c, i) => (headers[i] = String(cellValue(c.value) ?? '').trim()));
    const rows: Row[] = [];
    ws.eachRow((r, n) => {
      if (n === 1) return;
      const row: Row = { _sheet: name, _row: n };
      headers.forEach((h, i) => h && (row[h] = cellValue(r.getCell(i).value)));
      if (Object.keys(row).some((k) => !k.startsWith('_') && row[k] !== null)) rows.push(row);
    });
    return rows;
  };
  return {
    studios: read('Studio'), sets: read('BoiCanh'), packages: read('GoiThue'),
    staff: read('NhanSu'), addons: read('DichVu'),
  };
}

// ============================================================= kiểm tra dữ liệu
const errors: string[] = [];
const warnings: string[] = [];
const at = (r: Row) => `[${r._sheet} dòng ${r._row}]`;

function text(r: Row, col: string, required = false, max?: number): string | null {
  const v = r[col];
  const s = v === null || v === undefined ? null : String(v).trim();
  if (!s) {
    if (required) errors.push(`${at(r)} thiếu ${col}`);
    return null;
  }
  if (max && s.length > max) errors.push(`${at(r)} ${col} dài quá ${max} ký tự`);
  return s;
}

function num(r: Row, col: string, { required = false, min = 0, int = true } = {}): number | null {
  const v = r[col];
  if (v === null || v === undefined || v === '') {
    if (required) errors.push(`${at(r)} thiếu ${col}`);
    return null;
  }
  const n = typeof v === 'number' ? v : Number(String(v).replace(/[.,\s]/g, ''));
  if (!Number.isFinite(n) || n < min || (int && !Number.isInteger(n))) {
    errors.push(`${at(r)} ${col} = "${v}" không hợp lệ (cần số ${int ? 'nguyên ' : ''}>= ${min})`);
    return null;
  }
  return n;
}

function time(r: Row, col: string, fallback: string): string {
  const v = r[col];
  if (v === null) return fallback;
  // Ô số kiểu thời gian của Excel: 0.375 = 09:00
  if (typeof v === 'number' && v >= 0 && v <= 1) {
    const m = Math.round(v * 24 * 60);
    return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
  }
  const s = String(v).trim().replace('h', ':').replace(/^(\d):/, '0$1:');
  if (!/^([01]\d|2[0-3]):[0-5]\d$|^24:00$/.test(s)) {
    errors.push(`${at(r)} ${col} = "${v}" phải dạng HH:mm (vd 08:00, 24:00)`);
    return fallback;
  }
  return s;
}

const yes = (v: unknown) => String(v ?? '').trim().toLowerCase() === 'có';

// ============================================================= ảnh
type SetImages = { avatar: string; album: string[]; test: string[] };

async function listImages(dir: string): Promise<string[]> {
  if (!existsSync(dir)) return [];
  const entries = await fs.readdir(dir, { withFileTypes: true });
  return entries
    .filter((e) => e.isFile() && IMAGE_EXT.includes(extname(e.name).toLowerCase()))
    .map((e) => join(dir, e.name))
    .sort((a, b) => a.localeCompare(b, 'vi', { numeric: true }));
}

/** Chia ảnh 1 bối cảnh thành: ảnh đại diện + album (đưa vào hệ thống) và ảnh kiểm thử. */
async function planSetImages(maSet: string): Promise<SetImages | null> {
  const dir = join(IMAGE_DIR, maSet);
  const all = await listImages(dir);
  const testDir = (await fs.readdir(dir).catch(() => [] as string[])).find((n) => n.toLowerCase() === 'test');
  let indexed: string[];
  let test: string[];
  if (testDir) {
    indexed = all;
    test = await listImages(join(dir, testDir));
  } else {
    indexed = all.filter((_, i) => (i + 1) % TEST_PER_SET_AUTO !== 0);
    test = all.filter((_, i) => (i + 1) % TEST_PER_SET_AUTO === 0);
  }
  if (indexed.length === 0) {
    errors.push(`[Ảnh] thư mục ${relative(SEED_DIR, dir)} không có ảnh nào (JPG/PNG/WEBP)`);
    return null;
  }
  const avatarIdx = Math.max(0, indexed.findIndex((p) => /^dai_dien/i.test(p.split(/[\\/]/).pop()!)));
  const avatar = indexed[avatarIdx];
  let album = indexed.filter((_, i) => i !== avatarIdx);
  if (album.length > MAX_SET_IMAGES) {
    warnings.push(`[Ảnh] ${maSet}: ${album.length} ảnh album, app chỉ nhận ${MAX_SET_IMAGES} -> ${album.length - MAX_SET_IMAGES} ảnh dư chuyển sang ảnh kiểm thử`);
    test = [...test, ...album.slice(MAX_SET_IMAGES)];
    album = album.slice(0, MAX_SET_IMAGES);
  }
  if (test.length === 0) warnings.push(`[Ảnh] ${maSet}: không có ảnh kiểm thử -> bối cảnh này không được đánh giá AI`);
  for (const p of [avatar, ...album]) {
    const size = (await fs.stat(p)).size;
    if (size > BIG_IMAGE_BYTES) {
      warnings.push(`[Ảnh] ${relative(SEED_DIR, p)} nặng ${(size / 1048576).toFixed(1)} MB — nên nén < 3 MB cho app tải nhanh`);
    }
  }
  return { avatar, album, test };
}

/** Chép ảnh vào backend/uploads/seed/<mã>/01.jpg ... và trả về URL "/uploads/seed/...". */
async function copyImages(code: string, files: string[]): Promise<string[]> {
  const dest = join(UPLOADS_ROOT, 'seed', code);
  await fs.rm(dest, { recursive: true, force: true }); // chạy lại -> không để rác ảnh cũ
  await fs.mkdir(dest, { recursive: true });
  const urls: string[] = [];
  for (const [i, src] of files.entries()) {
    const name = `${String(i + 1).padStart(2, '0')}${extname(src).toLowerCase().replace('.jpeg', '.jpg')}`;
    await fs.copyFile(src, join(dest, name));
    urls.push(`/uploads/seed/${code}/${name}`);
  }
  return urls;
}

// ============================================================= chương trình chính
async function main() {
  console.log(`File Excel : ${EXCEL_FILE}`);
  console.log(`Thư mục ảnh: ${IMAGE_DIR}\n`);
  if (!existsSync(EXCEL_FILE)) throw new Error('Không tìm thấy file Excel');

  const book = await readWorkbook(EXCEL_FILE);

  // ---- 1) Studio được chọn nhập
  const studioRows = book.studios.filter((r) => {
    const code = text(r, 'ma_studio', true)?.toUpperCase();
    if (!code) return false;
    if (ONLY && !ONLY.includes(code)) return false;
    if (String(r.trang_thai_xin_phep ?? '').trim() === 'Từ chối') {
      warnings.push(`${at(r)} ${code} "Từ chối" -> bỏ qua (nhớ xoá dữ liệu + ảnh của studio này)`);
      return false;
    }
    if (!yes(r.nhap_vao_app)) return false;
    if (String(r.trang_thai_xin_phep ?? '').trim() !== 'Đồng ý') {
      warnings.push(`${at(r)} ${code} chưa "Đồng ý" -> được nhập để thử, nhưng KHÔNG đưa vào báo cáo / demo`);
    }
    return true;
  });
  const codes = new Set<string>();
  for (const r of studioRows) {
    const code = String(r.ma_studio).toUpperCase();
    if (codes.has(code)) errors.push(`${at(r)} trùng ma_studio ${code}`);
    codes.add(code);
  }
  const ofStudio = (rows: Row[]) => (code: string) =>
    rows.filter((r) => String(r.ma_studio ?? '').trim().toUpperCase() === code);
  const ofSet = (code: string) =>
    book.packages.filter((r) => String(r.ma_set ?? '').trim().toUpperCase() === code);

  // ---- 2) Kiểm tra + dựng dữ liệu (chưa ghi gì)
  const plans: StudioPlan[] = [];
  for (const r of studioRows) {
    const code = String(r.ma_studio).toUpperCase();
    const district = text(r, 'quan', true);
    if (district && !DISTRICTS.includes(district)) {
      errors.push(`${at(r)} quan "${district}" không có trong danh sách: ${DISTRICTS.join(', ')}`);
    }
    const lat = num(r, 'vi_do', { int: false, min: -90 });
    const lng = num(r, 'kinh_do', { int: false, min: -180 });
    if ((lat === null) !== (lng === null)) errors.push(`${at(r)} cần điền cả vi_do và kinh_do (hoặc để trống cả hai)`);
    if (lat !== null && (lat < 20.5 || lat > 21.5 || lng! < 105.3 || lng! > 106.1)) {
      warnings.push(`${at(r)} toạ độ ${lat}, ${lng} không nằm trong Hà Nội — kiểm tra lại (có thể đảo vĩ độ / kinh độ)`);
    }
    const email = text(r, 'email_chu_studio', true)?.toLowerCase() ?? '';
    if (email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) errors.push(`${at(r)} email_chu_studio không hợp lệ`);
    const phone = text(r, 'so_dien_thoai', true, 20);

    const setRows = ofStudio(book.sets)(code);
    if (setRows.length === 0) errors.push(`${at(r)} ${code} chưa có bối cảnh nào ở sheet BoiCanh`);
    const sets: SetPlan[] = [];
    for (const s of setRows) {
      const maSet = text(s, 'ma_set', true)?.toUpperCase();
      if (!maSet) continue;
      const pkgRows = ofSet(maSet);
      if (pkgRows.length === 0) errors.push(`${at(s)} ${maSet} chưa có gói thuê nào ở sheet GoiThue`);
      const pkgMax = pkgRows.map((p) => num(p, 'so_nguoi_toi_da', { min: 1 }) ?? 0);
      const capacity = num(s, 'suc_chua', { min: 1 }) ?? (Math.max(0, ...pkgMax) || 10);
      const packages = pkgRows.map((p) => {
        const max = num(p, 'so_nguoi_toi_da', { min: 1 }) ?? capacity;
        const included = num(p, 'so_nguoi_bao_gom', { min: 1 }) ?? max;
        if (max > capacity) errors.push(`${at(p)} so_nguoi_toi_da ${max} > sức chứa bối cảnh ${capacity}`);
        if (included > max) errors.push(`${at(p)} so_nguoi_bao_gom ${included} > so_nguoi_toi_da ${max}`);
        const minutes = num(p, 'thoi_luong_phut', { required: true, min: 30 }) ?? 60;
        if (minutes % 30 !== 0) errors.push(`${at(p)} thoi_luong_phut nên là bội số của 30`);
        return {
          name: text(p, 'ten_goi', true, 100) ?? '',
          description: text(p, 'mo_ta'),
          duration_minutes: minutes,
          price: num(p, 'gia', { required: true, min: 1000 }) ?? 0,
          included_people: included,
          extra_person_fee: num(p, 'phi_them_nguoi') ?? 0,
          max_people: max,
        };
      });
      sets.push({
        code: maSet,
        name: text(s, 'ten_set', true, 100) ?? '',
        style_tag: text(s, 'phong_cach', false, 50),
        description: text(s, 'mo_ta'),
        capacity,
        packages,
        images: await planSetImages(maSet),
      });
    }
    const orphanPkg = book.packages.filter((p) => String(p.ma_set ?? '').toUpperCase().startsWith(code + '-')
      && !sets.some((s) => s.code === String(p.ma_set).toUpperCase()));
    orphanPkg.forEach((p) => errors.push(`${at(p)} ma_set ${p.ma_set} không có ở sheet BoiCanh`));

    const staff = ofStudio(book.staff)(code).map((s) => {
      const role = ROLE[String(s.vai_tro ?? '').trim().toLowerCase()];
      if (!role) errors.push(`${at(s)} vai_tro phải là "Thợ ảnh" hoặc "Thợ trang điểm"`);
      return { full_name: text(s, 'ho_ten', true, 100) ?? '', role, phone: text(s, 'so_dien_thoai', false, 20) };
    });
    const addons = ofStudio(book.addons)(code).map((a) => {
      const role = ROLE[String(a.vai_tro ?? '').trim().toLowerCase()];
      const unit = UNIT[String(a.don_vi ?? '').trim().toLowerCase()];
      if (!role) errors.push(`${at(a)} vai_tro phải là "Thợ ảnh" hoặc "Thợ trang điểm"`);
      if (!unit) errors.push(`${at(a)} don_vi phải là "Theo lượt", "Theo giờ" hoặc "Theo người"`);
      if (role && !staff.some((s) => s.role === role)) {
        warnings.push(`${at(a)} "${a.ten_dich_vu}" chưa có người đúng vai trò ở NhanSu -> khách chưa đặt được dịch vụ này`);
      }
      return { name: text(a, 'ten_dich_vu', true, 100) ?? '', role, unit, price: num(a, 'gia', { required: true }) ?? 0, description: text(a, 'mo_ta') };
    });

    plans.push({
      code,
      ownerEmail: email,
      ownerName: text(r, 'ten_chu_studio', false, 100) ?? `Chủ ${r.ten_studio ?? code}`,
      studio: {
        name: text(r, 'ten_studio', true, 150) ?? '',
        address: text(r, 'dia_chi', true) ?? '',
        district: district ?? '',
        phone: phone ?? '',
        description: text(r, 'mo_ta'),
        open_time: time(r, 'gio_mo_cua', '08:00'),
        close_time: time(r, 'gio_dong_cua', '22:00'),
        evening_start_time: time(r, 'gio_bat_dau_toi', '18:00'),
        evening_surcharge_pct: num(r, 'phu_thu_toi_pct') ?? 0,
        weekend_surcharge_pct: num(r, 'phu_thu_cuoi_tuan_pct') ?? 0,
        latitude: lat,
        longitude: lng,
      },
      covers: await listImages(join(IMAGE_DIR, code)),
      sets,
      staff,
      addons,
    });
  }
  for (const p of plans) {
    if (p.studio.open_time >= p.studio.close_time) errors.push(`[Studio ${p.code}] gio_mo_cua phải trước gio_dong_cua`);
  }

  // ---- Báo cáo kiểm tra
  for (const p of plans) {
    console.log(`${p.code}  ${p.studio.name}  (${p.ownerEmail})`);
    for (const s of p.sets) {
      const im = s.images;
      console.log(`   ${s.code}  ${s.name || '(chưa có tên)'} — ${s.packages.length} gói` +
        (im ? `, ảnh: 1 đại diện + ${im.album.length} album, ${im.test.length} kiểm thử` : ', CHƯA CÓ ẢNH'));
    }
  }
  if (plans.length === 0) console.log('Không có studio nào được chọn (cột nhap_vao_app = "Có"?).');
  if (warnings.length) console.log(`\n⚠ ${warnings.length} lưu ý:\n  - ${warnings.join('\n  - ')}`);
  if (errors.length) {
    errors.sort((a, b) => a.localeCompare(b, 'vi', { numeric: true }));
    console.log(`\n✘ ${errors.length} lỗi — sửa file Excel / thư mục ảnh rồi chạy lại (chưa ghi gì vào DB):\n  - ${errors.join('\n  - ')}`);
    process.exitCode = 1;
    return;
  }
  if (CHECK_ONLY) {
    console.log('\n✔ Dữ liệu hợp lệ (chế độ --kiem-tra: chưa ghi gì).');
    return;
  }

  // ---- 3) Ghi vào DB
  const prisma = new PrismaService();
  await prisma.$connect();
  try {
    const setIds: string[] = [];
    const seeded: SeededStudio[] = [];
    if (AI_ONLY) {
      for (const p of plans) {
        const studio = await prisma.studio.findFirst({
          where: { name: p.studio.name, owner: { email: p.ownerEmail } },
          include: { sets: { where: { is_active: true } } },
        });
        if (!studio) {
          console.log(`  ${p.code}: chưa nhập -> bỏ qua`);
          continue;
        }
        setIds.push(...studio.sets.map((s) => s.id));
        seeded.push({ plan: p, studioId: studio.id, sets: studio.sets.map((s) => ({ id: s.id, name: s.name })) });
      }
    } else {
      const password = process.env.SEED_OWNER_PASSWORD;
      if (!password || password.length < 8) {
        throw new Error('Thêm SEED_OWNER_PASSWORD=<mật khẩu ít nhất 8 ký tự> vào backend/.env (mật khẩu cho các tài khoản chủ studio mới)');
      }
      const hash = await bcrypt.hash(password, BCRYPT_COST);
      console.log('\nĐang ghi vào cơ sở dữ liệu...');
      for (const p of plans) {
        const result = await seedStudio(prisma, p, hash);
        if (result) {
          seeded.push(result);
          setIds.push(...result.sets.map((s) => s.id));
        }
      }
    }

    // ---- 4) AI mã hoá ảnh
    if (SKIP_AI) {
      console.log('\nBỏ qua AI (--khong-ai). Bật ai-service rồi chạy: npm run seed:studios -- --chi-ai');
    } else if (setIds.length) {
      await runAi(prisma, setIds);
    }

    // ---- 5) Danh sách ảnh kiểm thử cho script đánh giá AI
    if (seeded.length) await writeManifest(seeded);
  } finally {
    await prisma.$disconnect();
  }
}

type SetPlan = {
  code: string; name: string; style_tag: string | null; description: string | null; capacity: number;
  packages: { name: string; description: string | null; duration_minutes: number; price: number;
    included_people: number; extra_person_fee: number; max_people: number }[];
  images: SetImages | null;
};
type StudioPlan = {
  code: string; ownerEmail: string; ownerName: string;
  studio: { name: string; address: string; district: string; phone: string; description: string | null;
    open_time: string; close_time: string; evening_start_time: string; evening_surcharge_pct: number;
    weekend_surcharge_pct: number; latitude: number | null; longitude: number | null };
  covers: string[];
  sets: SetPlan[];
  staff: { full_name: string; role: StaffRole; phone: string | null }[];
  addons: { name: string; role: StaffRole; unit: AddonUnit; price: number; description: string | null }[];
};
type SeededStudio = { plan: StudioPlan; studioId: string; sets: { id: string; name: string }[] };

async function seedStudio(prisma: PrismaService, p: StudioPlan, passwordHash: string): Promise<SeededStudio | null> {
  // Tài khoản chủ studio
  let owner = await prisma.user.findUnique({ where: { email: p.ownerEmail } });
  if (owner && owner.role === 'admin') {
    console.log(`  ✘ ${p.code}: ${p.ownerEmail} là tài khoản admin -> đổi email khác`);
    return null;
  }
  if (!owner) {
    owner = await prisma.user.create({
      data: { email: p.ownerEmail, full_name: p.ownerName, password_hash: passwordHash, role: 'studio_owner' },
    });
  } else if (owner.role !== 'studio_owner') {
    owner = await prisma.user.update({ where: { id: owner.id }, data: { role: 'studio_owner' } });
  }

  // Đã nhập trước đó?
  const old = await prisma.studio.findFirst({
    where: { owner_id: owner.id, name: p.studio.name },
    include: { _count: { select: { bookings: true } } },
  });
  if (old && old._count.bookings > 0) {
    console.log(`  - ${p.code}: đã có ${old._count.bookings} đơn đặt -> giữ nguyên, không nhập lại`);
    const sets = await prisma.studioSet.findMany({ where: { studio_id: old.id, is_active: true }, select: { id: true, name: true } });
    return { plan: p, studioId: old.id, sets };
  }

  // Chép ảnh (ngoài transaction — chạy lại sẽ ghi đè cùng tên file)
  const setUrls = new Map<string, { avatar: string; album: string[] }>();
  for (const s of p.sets) {
    const [avatar, ...album] = await copyImages(s.code, [s.images!.avatar, ...s.images!.album]);
    setUrls.set(s.code, { avatar, album });
  }
  const coverUrls = p.covers.length
    ? await copyImages(p.code, p.covers)
    : [setUrls.get(p.sets[0].code)!.avatar]; // không có ảnh bìa -> dùng ảnh đại diện bối cảnh đầu

  const searchText = normalizeSearch(
    [p.studio.name, p.studio.district, p.studio.address, ...p.sets.flatMap((s) => [s.name, s.style_tag ?? ''])].join(' '),
  );

  const studioId = await prisma.$transaction(async (tx) => {
    if (old) await wipeStudio(tx, old.id);
    const studio = await tx.studio.create({
      data: { ...p.studio, owner_id: owner.id, status: 'active', search_text: searchText },
    });
    await tx.studioImage.createMany({
      data: coverUrls.map((url, i) => ({ studio_id: studio.id, url, is_cover: i === 0, sort_order: i })),
    });
    for (const s of p.sets) {
      const urls = setUrls.get(s.code)!;
      await tx.studioSet.create({
        data: {
          studio_id: studio.id, name: s.name, style_tag: s.style_tag, description: s.description,
          capacity: s.capacity, avatar_url: urls.avatar,
          images: { create: urls.album.map((url, i) => ({ url, sort_order: i })) },
          packages: {
            create: s.packages.map((k) => ({
              ...k, price: new Prisma.Decimal(k.price), extra_person_fee: new Prisma.Decimal(k.extra_person_fee),
            })),
          },
        },
      });
    }
    if (p.staff.length) {
      await tx.staffMember.createMany({ data: p.staff.map((x) => ({ ...x, studio_id: studio.id })) });
    }
    if (p.addons.length) {
      await tx.addonService.createMany({
        data: p.addons.map((a) => ({ ...a, price: new Prisma.Decimal(a.price), studio_id: studio.id })),
      });
    }
    return studio.id;
  }, { timeout: 60_000 });

  const sets = await prisma.studioSet.findMany({ where: { studio_id: studioId }, select: { id: true, name: true }, orderBy: { created_at: 'asc' } });
  console.log(`  ✔ ${p.code} ${p.studio.name}: ${old ? 'nhập lại' : 'nhập mới'} ${sets.length} bối cảnh, ${coverUrls.length} ảnh bìa`);
  return { plan: p, studioId, sets };
}

/** Xoá studio đã nhập trước đó (chỉ gọi khi studio CHƯA có đơn đặt nào). */
async function wipeStudio(tx: Prisma.TransactionClient, studioId: string) {
  const sets = await tx.studioSet.findMany({ where: { studio_id: studioId }, select: { id: true } });
  const setIds = sets.map((s) => s.id);
  const convs = await tx.conversation.findMany({ where: { studio_id: studioId }, select: { id: true } });
  await tx.message.deleteMany({ where: { conversation_id: { in: convs.map((c) => c.id) } } });
  await tx.conversation.deleteMany({ where: { studio_id: studioId } });
  await tx.review.deleteMany({ where: { studio_id: studioId } });
  await tx.favorite.deleteMany({ where: { studio_id: studioId } });
  await tx.viewHistory.deleteMany({ where: { studio_id: studioId } });
  await tx.rentalPackage.deleteMany({ where: { set_id: { in: setIds } } });
  await tx.setImage.deleteMany({ where: { set_id: { in: setIds } } });
  await tx.studioSet.deleteMany({ where: { studio_id: studioId } });
  await tx.studioImage.deleteMany({ where: { studio_id: studioId } });
  await tx.addonService.deleteMany({ where: { studio_id: studioId } });
  await tx.staffMember.deleteMany({ where: { studio_id: studioId } });
  await tx.studio.delete({ where: { id: studioId } });
}

/** Gọi ai-service mã hoá ảnh đại diện + ảnh album của các bối cảnh rồi dựng lại FAISS index. */
async function runAi(prisma: PrismaService, setIds: string[]) {
  const config = new ConfigService();
  const url = config.get<string>('AI_SERVICE_URL') ?? 'http://localhost:8000';
  try {
    await axios.get(`${url}/health`, { timeout: 5000 });
  } catch {
    console.log(`\n⚠ Không gọi được ai-service ở ${url} -> ảnh CHƯA được AI mã hoá.`);
    console.log('  Bật ai-service (xem ai-service/README.md) rồi chạy: npm run seed:studios -- --chi-ai');
    return;
  }
  console.log(`\nAI đang mã hoá ảnh của ${setIds.length} bối cảnh (mỗi ảnh ~0,2–1 giây)...`);
  const ai = new AiService(new HttpService(axios.create()), config, prisma);
  const started = Date.now();
  const aiWarnings = await ai.indexSets(setIds);
  const [count] = await prisma.$queryRaw<{ sets: number; images: number }[]>`
    SELECT
      (SELECT COUNT(*)::int FROM studio_sets WHERE id = ANY(${setIds}::text[]) AND clip_embedding IS NOT NULL) AS sets,
      (SELECT COUNT(*)::int FROM set_images WHERE set_id = ANY(${setIds}::text[]) AND clip_embedding IS NOT NULL) AS images
  `;
  console.log(`  ✔ ${count.sets} ảnh đại diện + ${count.images} ảnh album đã có vector (${((Date.now() - started) / 1000).toFixed(1)} giây)`);
  aiWarnings.forEach((w) => console.log(`  ⚠ ${w}`));
}

/** seed_data/test_manifest.json: ảnh kiểm thử + bối cảnh đúng -> dùng cho script đánh giá AI. */
async function writeManifest(seeded: SeededStudio[]) {
  const items: Record<string, string>[] = [];
  const sets: Record<string, string | number>[] = [];
  for (const st of seeded) {
    for (const [i, s] of st.plan.sets.entries()) {
      const db = st.sets.find((x) => x.name === s.name) ?? st.sets[i];
      if (!db || !s.images) continue;
      sets.push({
        ma_set: s.code, set_id: db.id, set_name: s.name, ma_studio: st.plan.code,
        studio_name: st.plan.studio.name, indexed_images: 1 + s.images.album.length, test_images: s.images.test.length,
      });
      for (const img of s.images.test) {
        items.push({
          image: relative(SEED_DIR, img).split('\\').join('/'),
          ma_set: s.code, set_id: db.id, ma_studio: st.plan.code,
        });
      }
    }
  }
  // Giữ ảnh kiểm thử của studio không chạy lần này (khi dùng --chi)
  if (ONLY && existsSync(MANIFEST_FILE)) {
    const prev = JSON.parse(await fs.readFile(MANIFEST_FILE, 'utf8'));
    const keep = (x: { ma_studio: string }) => !seeded.some((st) => st.plan.code === x.ma_studio);
    items.unshift(...(prev.items ?? []).filter(keep));
    sets.unshift(...(prev.sets ?? []).filter(keep));
  }
  await fs.writeFile(
    MANIFEST_FILE,
    JSON.stringify({ created_at: new Date().toISOString(), image_root: 'seed_data', sets, items }, null, 2),
  );
  console.log(`\nĐã ghi ${relative(process.cwd(), MANIFEST_FILE)}: ${sets.length} bối cảnh, ${items.length} ảnh kiểm thử.`);
}

main().catch((err) => {
  console.error(`\n✘ ${err instanceof Error ? err.message : err}`);
  process.exit(1);
});
