// Kiểm thử đầu-cuối mô hình gói thuê trên backend thật + Postgres thật
import { readFileSync } from 'fs';
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1';
let pass = 0, fail = 0;
const ok = (cond, name, extra = '') => {
  if (cond) { pass++; console.log('  ✔', name); }
  else { fail++; console.log('  ✘', name, extra); }
};
async function call(method, path, token, body, isForm = false) {
  const res = await fetch(API + path, {
    method,
    headers: {
      ...(token && { Authorization: `Bearer ${token}` }),
      ...(!isForm && body && { 'Content-Type': 'application/json' }),
    },
    body: isForm ? body : body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = await res.json(); } catch {}
  return { status: res.status, data };
}
const login = async (email, password) => (await call('POST', '/auth/login', null, { email, password })).data.access_token;
const pad = (n) => String(n).padStart(2, '0');
// Ngày cụ thể ở tương lai: thứ Tư 11/11/2026 và thứ Bảy 14/11/2026
// Ngày thứ Tư / thứ Bảy gần nhất trong tương lai (>= 2 ngày tới) — tránh test hỏng khi ngày cố định đã qua
const nextDow = (dow) => { const d = new Date(Date.now() + 2 * 86400000); while (d.getDay() !== dow) d.setDate(d.getDate() + 1); return d.toLocaleDateString('sv-SE', { timeZone: 'Asia/Ho_Chi_Minh' }); };
const WED = nextDow(3), SAT = nextDow(6);
const iso = (d, hhmm) => `${d}T${hhmm}:00`;

console.log('1. Tài khoản');
let r = await call('POST', '/auth/register', null, { full_name: 'Chủ A', email: 'owner@t.test', password: '12345678', role: 'studio_owner' });
ok(r.status === 201 && r.data.role === 'studio_owner', 'đăng ký chủ studio', JSON.stringify(r.data));
r = await call('POST', '/auth/register', null, { full_name: 'Khách', email: 'khach@t.test', password: '12345678' });
ok(r.status === 201 && r.data.role === 'user', 'đăng ký khách (mặc định user)');
r = await call('POST', '/auth/register', null, { full_name: 'Hacker', email: 'h@t.test', password: '12345678', role: 'admin' });
ok(r.status === 400, 'không tự đăng ký admin được');
const owner = await login('owner@t.test', '12345678');
const khach = await login('khach@t.test', '12345678');
const admin = await login('admin@t.test', 'Admin@123');

console.log('2. Studio + giờ mở cửa + phụ thu');
r = await call('POST', '/studios', owner, { name: 'X', address: 'a', district: 'Đống Đa', phone: '0900', open_time: '18:00', close_time: '18:30' });
ok(r.status === 400, 'từ chối giờ mở cửa < 1 tiếng');
r = await call('POST', '/studios', owner, {
  name: 'Studio Test', address: '1 Phố A', district: 'Đống Đa', phone: '0900000001',
  open_time: '08:00', close_time: '18:00', evening_start_time: '16:00', evening_surcharge_pct: 20, weekend_surcharge_pct: 10,
});
ok(r.status === 201 && r.data.status === 'pending' && r.data.close_time === '18:00', 'tạo studio (chờ duyệt, giờ riêng)');
const studioId = r.data.id;
r = await call('POST', '/studios', owner, { name: 'Studio Rỗng', address: 'b', district: 'Tây Hồ', phone: '0900000002' });
const emptyStudioId = r.data.id;
ok(r.data.open_time === '08:00' && r.data.close_time === '22:00', 'mặc định 08:00–22:00');

console.log('3. Ảnh + set');
const form = new FormData();
form.append('image', new Blob([readFileSync(new URL('./set.png', import.meta.url))], { type: 'image/png' }), 'set.png');
r = await call('POST', `/studios/${studioId}/media`, owner, form, true);
ok(r.status === 201 && r.data.url.startsWith('/uploads/sets/'), 'tải ảnh set', JSON.stringify(r.data));
const avatar = r.data.url;
r = await call('POST', `/studios/${studioId}/sets`, owner, { name: 'Vintage', style_tag: 'vintage', capacity: 6, avatar_url: avatar });
ok(r.status === 201 && Array.isArray(r.data.ai_warnings), 'tạo set (studio chờ duyệt: không encode)');
const setId = r.data.id;

console.log('4. Gói thuê');
const pkgBody = { name: 'Gói 2 tiếng', duration_minutes: 120, price: 300000, included_people: 2, extra_person_fee: 50000, max_people: 6 };
r = await call('POST', `/studios/${studioId}/sets/${setId}/packages`, owner, { ...pkgBody, duration_minutes: 90 + 15 });
ok(r.status === 400, 'từ chối thời lượng không chia hết 30 phút', JSON.stringify(r.data?.message));
r = await call('POST', `/studios/${studioId}/sets/${setId}/packages`, owner, { ...pkgBody, max_people: 8 });
ok(r.status === 400 && /sức chứa/.test(r.data.message), 'từ chối vượt sức chứa set');
r = await call('POST', `/studios/${studioId}/sets/${setId}/packages`, owner, { ...pkgBody, included_people: 4, max_people: 3 });
ok(r.status === 400, 'từ chối max < included');
r = await call('POST', `/studios/${studioId}/sets/${setId}/packages`, owner, { ...pkgBody, duration_minutes: 660 });
ok(r.status === 400 && /vượt giờ mở cửa/.test(r.data.message), 'từ chối gói dài hơn giờ mở cửa');
r = await call('POST', `/studios/${studioId}/sets/${setId}/packages`, khach, pkgBody);
ok(r.status === 403, 'khách không tạo được gói');
r = await call('POST', `/studios/${studioId}/sets/${setId}/packages`, owner, pkgBody);
ok(r.status === 201 && r.data.price === 300000 && r.data.extra_person_fee === 50000, 'tạo gói 2 tiếng (giá trả về là number)', JSON.stringify(r.data));
const pkgId = r.data.id;
r = await call('POST', `/studios/${studioId}/sets/${setId}/packages`, owner, { name: 'Theo giờ', duration_minutes: 60, price: 180000, included_people: 1, extra_person_fee: 30000, max_people: 6 });
const hourPkgId = r.data.id;
ok(r.status === 201, 'tạo gói theo giờ');
r = await call('GET', `/studios/mine/${studioId}`, owner);
ok(r.status === 200 && r.data.sets[0].packages.length === 2, 'chủ studio xem studio của mình kèm gói');

console.log('5. Duyệt');
r = await call('GET', `/studios/${studioId}`, null);
ok(r.status === 404, 'khách chưa xem được studio chờ duyệt');
r = await call('PATCH', `/admin/studios/${emptyStudioId}/approve`, admin);
ok(r.status === 400, 'không duyệt studio chưa có gói', JSON.stringify(r.data?.message));
r = await call('PATCH', `/admin/studios/${studioId}/approve`, admin);
ok(r.status === 200, 'duyệt studio có gói (AI tắt -> vẫn duyệt được)', JSON.stringify(r.data));

console.log('6. Danh sách / lọc giá');
r = await call('GET', '/studios', null);
const card = r.data.data.find((s) => s.id === studioId);
ok(card && card.min_price === 180000 && card.min_price_minutes === 60, 'thẻ studio: Từ 180.000đ / 60 phút', JSON.stringify(card));
r = await call('GET', '/studios?min_price=250000', null);
ok(r.data.data.some((s) => s.id === studioId), 'lọc min_price=250000 vẫn thấy (có gói 300k)');
r = await call('GET', '/studios?max_price=100000', null);
ok(!r.data.data.some((s) => s.id === studioId), 'lọc max_price=100000 không thấy');
r = await call('GET', '/studios?style_tag=vintage&max_price=200000', null);
ok(r.data.data.some((s) => s.id === studioId), 'lọc phong cách + giá cùng lúc (AND)');
r = await call('GET', `/studios/${studioId}`, null);
ok(r.status === 200 && r.data.sets[0].packages[0].price === 180000, 'chi tiết studio: gói sắp theo giá tăng dần');

console.log('7. Giờ trống + giá');
r = await call('GET', `/studios/${studioId}/availability?date=${WED}&package_id=${pkgId}&num_people=4`, null);
const slots = r.data.available_slots ?? [];
ok(r.status === 200 && slots.length === 17, `gói 2 tiếng, mở 8–18h: 17 giờ bắt đầu (08:00…16:00), nhận ${slots.length}`, JSON.stringify(r.data).slice(0, 300));
ok(slots[0]?.start === '08:00' && slots[0]?.end === '10:00' && slots[0]?.price === 400000, '08:00 4 người = 300k + 2×50k = 400.000đ');
const s16 = slots.find((s) => s.start === '16:00');
ok(s16?.price === 480000 && s16?.surcharge_pct === 20, '16:00 có phụ thu giờ tối 20% = 480.000đ');
r = await call('GET', `/studios/${studioId}/availability?date=${SAT}&package_id=${pkgId}&num_people=2`, null);
ok(r.data.available_slots.find((s) => s.start === '16:00')?.price === 390000, 'thứ Bảy 16:00: phụ thu 30% → 390.000đ');
r = await call('GET', `/studios/${studioId}/availability?date=${WED}&package_id=${pkgId}&num_people=7`, null);
ok(r.status === 400, 'xem giá 7 người (> tối đa) → 400');

console.log('8. Đặt lịch');
r = await call('POST', '/bookings', khach, { package_id: pkgId, start_time: iso(WED, '09:00'), num_people: 4, special_note: 'mang 2 váy' });
ok(r.status === 201 && Number(r.data.total_amount) === 400000 && Number(r.data.deposit_amount) === 120000, 'đặt 09:00 4 người: 400.000đ, cọc 120.000đ', JSON.stringify(r.data));
ok(r.data.package_name === 'Gói 2 tiếng' && r.data.num_people === 4 && new Date(r.data.end_time).getHours() === 11, 'lưu tên gói, số người, kết thúc 11:00');
r = await call('POST', '/bookings', khach, { package_id: pkgId, start_time: iso(WED, '10:00'), num_people: 2, total_amount: 1 });
ok(r.status === 400, 'gửi kèm giá (total_amount) bị từ chối — app không được tự đặt giá');
r = await call('POST', '/bookings', khach, { package_id: pkgId, start_time: iso(WED, '10:00'), num_people: 2 });
ok(r.status === 409, 'trùng lịch 10:00 → 409');
r = await call('POST', '/bookings', khach, { package_id: hourPkgId, start_time: iso(WED, '10:30'), num_people: 1 });
ok(r.status === 409, 'gói khác nhưng CÙNG set vẫn bị chặn trùng lịch');
r = await call('POST', '/bookings', khach, { package_id: pkgId, start_time: iso(WED, '11:15'), num_people: 2 });
ok(r.status === 400, 'giờ lệch lưới 30 phút → 400');
r = await call('POST', '/bookings', khach, { package_id: pkgId, start_time: iso(WED, '17:00'), num_people: 2 });
ok(r.status === 400, 'kết thúc sau giờ đóng cửa → 400');
r = await call('POST', '/bookings', khach, { package_id: pkgId, start_time: iso(WED, '12:00'), num_people: 9 });
ok(r.status === 400, 'quá số người tối đa → 400');
r = await call('POST', '/bookings', khach, { package_id: pkgId, start_time: '2026-01-05T09:00:00', num_people: 2 });
ok(r.status === 400, 'thời điểm quá khứ → 400');
r = await call('POST', '/bookings', owner, { package_id: pkgId, start_time: iso(WED, '12:00'), num_people: 2 });
ok(r.status === 403, 'chủ studio không đặt lịch được');

r = await call('GET', `/studios/${studioId}/availability?date=${WED}&package_id=${hourPkgId}`, null);
const starts = r.data.available_slots.map((s) => s.start);
ok(!starts.includes('08:30') && starts.includes('08:00') && !starts.includes('10:30') && starts.includes('11:00'), 'gói 1 giờ: 08:00 trống, 08:30–10:30 bị chiếm, 11:00 trống', starts.join(' '));

console.log('9. Chống trùng lịch khi 6 người đặt cùng lúc');
const results = await Promise.all(Array.from({ length: 6 }, () =>
  call('POST', '/bookings', khach, { package_id: pkgId, start_time: iso(WED, '13:00'), num_people: 2 })));
const codes = results.map((x) => x.status).sort();
ok(codes.filter((c) => c === 201).length === 1 && codes.filter((c) => c === 409).length === 5, `đúng 1 thành công, 5 bị 409: [${codes}]`);

console.log('10. Danh sách lịch hẹn');
r = await call('GET', '/bookings', khach);
ok(r.data.data.every((b) => b.package_name && b.num_people), 'lịch hẹn của khách có tên gói + số người');
r = await call('GET', '/bookings/studio?status=pending', owner);
ok(r.status === 200 && r.data.total === 2 && r.data.data[0].customer.full_name === 'Khách', 'chủ studio thấy 2 đơn chờ, kèm tên khách', JSON.stringify(r.data).slice(0, 200));
ok(new Date(r.data.data[0].start_time) < new Date(r.data.data[1].start_time), 'đơn chờ xếp theo giờ chụp gần nhất trước');
r = await call('GET', '/bookings/studio', khach);
ok(r.status === 403 && /không có quyền/.test(r.data.message), 'khách gọi API chủ studio → 403 tiếng Việt');

console.log('11. Sửa / ẩn gói, giờ mở cửa');
r = await call('PUT', `/studios/${studioId}/sets/${setId}/packages/${pkgId}`, owner, { included_people: 7 });
ok(r.status === 400, 'sửa included_people > max_people cũ → 400 (kiểm tra sau khi gộp)');
r = await call('PUT', `/studios/${studioId}/sets/${setId}/packages/${pkgId}`, owner, { price: 350000 });
ok(r.status === 200 && r.data.price === 350000, 'đổi giá gói');
r = await call('GET', '/bookings', khach);
ok(r.data.data.some((b) => Number(b.total_amount) === 400000), 'đơn đã đặt GIỮ giá cũ (snapshot)');
r = await call('PUT', `/studios/${studioId}/sets/${setId}/packages/${hourPkgId}`, owner, { is_active: false });
ok(r.status === 200 && r.data.is_active === false, 'ẩn gói theo giờ');
r = await call('GET', `/studios/${studioId}/availability?date=${WED}&package_id=${hourPkgId}`, null);
ok(r.status === 404, 'gói đã ẩn không xem giờ trống được');
r = await call('GET', '/studios', null);
ok(r.data.data.find((s) => s.id === studioId).min_price === 350000, 'thẻ studio cập nhật "Từ 350.000đ" sau khi ẩn gói rẻ');
r = await call('PUT', `/studios/${studioId}`, owner, { close_time: '07:00' });
ok(r.status === 400, 'giờ đóng trước giờ mở → 400');
r = await call('PUT', `/studios/${studioId}`, owner, { open_time: '00:00', close_time: '24:00' });
ok(r.status === 200, 'chuyển sang mở 24/7 (00:00–24:00)');
r = await call('GET', `/studios/${studioId}/availability?date=${WED}&package_id=${pkgId}`, null);
ok(r.data.available_slots[0].start === '00:00' && r.data.available_slots.at(-1).start === '22:00', '24/7: giờ bắt đầu từ 00:00 đến 22:00 (gói 2 tiếng)');

console.log('12. Đã lưu');
await call('POST', `/studios/${studioId}/favorite`, khach);
r = await call('GET', '/favorites', khach);
ok(r.data[0]?.min_price === 350000, 'tab Đã lưu dùng cùng giá "Từ ..."', JSON.stringify(r.data));

console.log(`\nKẾT QUẢ: ${pass} đạt, ${fail} lỗi`);
process.exit(fail ? 1 : 0);
