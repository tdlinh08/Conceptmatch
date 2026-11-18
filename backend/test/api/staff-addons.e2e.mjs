// Kiểm thử đầu-cuối: nhân sự (thợ ảnh / trang điểm) + dịch vụ thêm + phân công
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1';
let pass = 0, fail = 0;
const ok = (cond, name, extra = '') => {
  if (cond) { pass++; console.log('  ✔', name); }
  else { fail++; console.log('  ✘', name, extra); }
};
async function call(method, path, token, body) {
  const res = await fetch(API + path, {
    method,
    headers: { ...(token && { Authorization: `Bearer ${token}` }), ...(body && { 'Content-Type': 'application/json' }) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = await res.json(); } catch {}
  return { status: res.status, data };
}
const login = async (email, password) => (await call('POST', '/auth/login', null, { email, password })).data.access_token;
const nextDow = (dow) => { const d = new Date(Date.now() + 2 * 86400000); while (d.getDay() !== dow) d.setDate(d.getDate() + 1); return d.toLocaleDateString('sv-SE', { timeZone: 'Asia/Ho_Chi_Minh' }); };
const D1 = nextDow(3), D2 = new Date(new Date(D1).getTime() + 7 * 86400000).toISOString().slice(0, 10); // thứ Tư
const iso = (d, t) => `${d}T${t}:00`;
const starts = (r) => (r.data?.available_slots ?? []).map((s) => s.start);

console.log('0. Chuẩn bị');
await call('POST', '/auth/register', null, { full_name: 'Chủ B', email: 'owner2@t.test', password: '12345678', role: 'studio_owner' });
await call('POST', '/auth/register', null, { full_name: 'Khách Hai', email: 'khach2@t.test', password: '12345678' });
const owner = await login('owner2@t.test', '12345678');
const khach = await login('khach2@t.test', '12345678');
const admin = await login('admin@t.test', 'Admin@123');
let r = await call('POST', '/studios', owner, { name: 'Studio Thợ', address: '2 Phố B', district: 'Cầu Giấy', phone: '0900000009', open_time: '08:00', close_time: '18:00', evening_start_time: '16:00', evening_surcharge_pct: 20 });
const sid = r.data.id;
const mkSet = async (name) => (await call('POST', `/studios/${sid}/sets`, owner, { name, capacity: 6, avatar_url: 'https://example.com/a.jpg' })).data.id;
const setA = await mkSet('Set A'), setB = await mkSet('Set B');
const pkgBody = { name: 'Gói 2 tiếng', duration_minutes: 120, price: 300000, included_people: 2, extra_person_fee: 50000, max_people: 6 };
const pkgA = (await call('POST', `/studios/${sid}/sets/${setA}/packages`, owner, pkgBody)).data.id;
const pkgB = (await call('POST', `/studios/${sid}/sets/${setB}/packages`, owner, pkgBody)).data.id;
r = await call('PATCH', `/admin/studios/${sid}/approve`, admin);
ok(r.status === 200, 'studio 2 set đã duyệt');

console.log('1. Nhân sự + dịch vụ');
r = await call('POST', `/studios/${sid}/staff`, owner, { full_name: 'An', role: 'photographer', phone: '0911' });
ok(r.status === 201 && r.data.role === 'photographer', 'thêm thợ ảnh An');
const an = r.data.id;
r = await call('POST', `/studios/${sid}/staff`, owner, { full_name: 'X', role: 'driver' });
ok(r.status === 400, 'vai trò sai → 400');
r = await call('POST', `/studios/${sid}/staff`, khach, { full_name: 'X', role: 'makeup' });
ok(r.status === 403, 'khách không thêm nhân sự được');
r = await call('POST', `/studios/${sid}/addons`, owner, { role: 'photographer', name: 'Thợ ảnh chụp', price: 200000, unit: 'per_hour' });
ok(r.status === 201 && r.data.price === 200000, 'tạo dịch vụ Thợ ảnh 200.000đ/giờ');
const PH = r.data.id;
r = await call('POST', `/studios/${sid}/addons`, owner, { role: 'makeup', name: 'Trang điểm', price: 150000, unit: 'per_person' });
const MK = r.data.id;
r = await call('POST', `/studios/${sid}/addons`, owner, { role: 'makeup', name: 'X', price: 1000, unit: 'per_minute' });
ok(r.status === 400, 'đơn vị tính sai → 400');
r = await call('GET', `/studios/${sid}`, null);
ok(r.data.staff_counts.photographer === 1 && r.data.staff_counts.makeup === 0, 'khách thấy số thợ: 1 thợ ảnh, 0 trang điểm');
ok(r.data.addons.length === 1 && r.data.addons[0].id === PH, 'dịch vụ trang điểm bị ẩn vì chưa có thợ trang điểm');
ok(!JSON.stringify(r.data).includes('0911'), 'không lộ SĐT nhân sự ra trang công khai');
r = await call('GET', `/studios/${sid}/availability?date=${D1}&package_id=${pkgA}&addon_ids=${MK}`, null);
ok(r.status === 400, 'xem giờ với dịch vụ chưa có người → 400', JSON.stringify(r.data));
r = await call('POST', `/studios/${sid}/staff`, owner, { full_name: 'Bình', role: 'makeup' });
const binh = r.data.id;
r = await call('GET', `/studios/${sid}`, null);
ok(r.data.addons.length === 2, 'thêm thợ trang điểm → dịch vụ trang điểm hiện ra');

console.log('2. Giá có dịch vụ');
r = await call('GET', `/studios/${sid}/availability?date=${D1}&package_id=${pkgA}&num_people=2&addon_ids=${PH}`, null);
const s8 = r.data.available_slots?.[0];
ok(s8?.start === '08:00' && s8.price === 700000 && r.data.addons_amount === 400000, '08:00 phòng 300k + thợ ảnh 2 giờ × 200k = 700.000đ', JSON.stringify(r.data).slice(0, 200));
ok(r.data.available_slots.find((s) => s.start === '16:00')?.price === 760000, '16:00: phụ thu 20% chỉ trên phòng → 360k + 400k = 760.000đ');
r = await call('GET', `/studios/${sid}/availability?date=${D1}&package_id=${pkgA}&num_people=3&addon_ids=${PH},${MK}`, null);
ok(r.data.available_slots?.[0]?.price === 1200000, '3 người + thợ ảnh + trang điểm: 350k + 400k + 3×150k = 1.200.000đ');
r = await call('GET', `/studios/${sid}/availability?date=${D1}&package_id=${pkgA}&addon_ids=${MK},${MK}`, null);
ok(r.status === 200, 'gửi trùng mã dịch vụ được gộp lại');

console.log('3. Hết thợ thì không đặt được dù phòng trống');
r = await call('POST', '/bookings', khach, { package_id: pkgA, start_time: iso(D1, '09:00'), num_people: 2, addon_ids: [PH] });
ok(r.status === 201 && Number(r.data.total_amount) === 700000 && Number(r.data.deposit_amount) === 210000, 'đặt Set A 09:00 + thợ ảnh: 700.000đ, cọc 210.000đ', JSON.stringify(r.data).slice(0, 300));
ok(r.data.addons?.length === 1 && r.data.addons[0].staff === null && r.data.addons[0].quantity === 2, 'đơn lưu dịch vụ (2 giờ), chưa phân công thợ');
const bA9 = r.data.id;
r = await call('GET', `/studios/${sid}/availability?date=${D1}&package_id=${pkgB}&addon_ids=${PH}`, null);
ok(starts(r)[0] === '11:00', 'Set B + thợ ảnh: 08:00–10:30 bị ẩn (thợ duy nhất bận 9–11)', starts(r).slice(0, 4).join(' '));
r = await call('GET', `/studios/${sid}/availability?date=${D1}&package_id=${pkgB}`, null);
ok(starts(r)[0] === '08:00', 'Set B không thuê thợ: vẫn đặt được từ 08:00');
r = await call('POST', '/bookings', khach, { package_id: pkgB, start_time: iso(D1, '10:00'), num_people: 2, addon_ids: [PH] });
ok(r.status === 409 && /thợ ảnh/.test(r.data.message), 'Set B 10:00 + thợ ảnh → 409 hết thợ ảnh', JSON.stringify(r.data));
r = await call('POST', '/bookings', khach, { package_id: pkgB, start_time: iso(D1, '10:00'), num_people: 2 });
ok(r.status === 201, 'Set B 10:00 không thợ → đặt được');

console.log('4. Thêm thợ → tăng sức chứa');
r = await call('POST', `/studios/${sid}/staff`, owner, { full_name: 'Chi', role: 'photographer' });
const chi = r.data.id;
r = await call('GET', `/studios/${sid}/availability?date=${D1}&package_id=${pkgB}&addon_ids=${PH}`, null);
ok(starts(r).includes('08:00'), 'có 2 thợ ảnh → Set B 08:00 + thợ ảnh hiện lại');
r = await call('POST', '/bookings', khach, { package_id: pkgB, start_time: iso(D1, '08:00'), num_people: 2, addon_ids: [PH] });
ok(r.status === 201, 'đặt Set B 08:00 + thợ ảnh');
const bB8 = r.data.id;

console.log('5. Xác nhận + phân công');
r = await call('PATCH', `/bookings/${bA9}/status`, owner, { status: 'confirmed' });
ok(r.status === 400 && /staff_assignments/.test(r.data.message), 'xác nhận đơn có thợ mà không phân công → 400');
r = await call('PATCH', `/bookings/${bA9}/status`, owner, { status: 'confirmed', staff_assignments: [{ role: 'photographer', staff_id: binh }] });
ok(r.status === 409, 'giao thợ trang điểm cho việc thợ ảnh → 409');
r = await call('GET', `/bookings/${bA9}/available-staff`, owner);
ok(r.status === 200 && r.data[0].staff.length === 2, 'gợi ý 2 thợ ảnh đang rảnh cho đơn A 9h', JSON.stringify(r.data));
r = await call('GET', `/bookings/${bA9}/available-staff`, khach);
ok(r.status === 403, 'khách không xem được danh sách thợ');
r = await call('PATCH', `/bookings/${bA9}/status`, owner, { status: 'confirmed', staff_assignments: [{ role: 'photographer', staff_id: an }] });
ok(r.status === 200 && r.data.status === 'confirmed', 'xác nhận A 9h, giao An');
r = await call('GET', `/bookings/${bB8}/available-staff`, owner);
ok(r.data[0].staff.length === 1 && r.data[0].staff[0].full_name === 'Chi', 'đơn B 8h chỉ còn gợi ý Chi (An bận 9–10)');
r = await call('PATCH', `/bookings/${bB8}/status`, owner, { status: 'confirmed', staff_assignments: [{ role: 'photographer', staff_id: an }] });
ok(r.status === 409, 'giao An cho đơn trùng giờ → 409');
r = await call('PATCH', `/bookings/${bB8}/status`, owner, { status: 'confirmed', staff_assignments: [{ role: 'photographer', staff_id: chi }] });
ok(r.status === 200, 'giao Chi cho đơn B 8h');
r = await call('GET', '/bookings', khach);
const mine = r.data.data.find((b) => b.id === bA9);
ok(mine?.addons?.[0]?.staff?.full_name === 'An', 'khách thấy thợ phụ trách: An');
r = await call('GET', '/bookings/studio', owner);
ok(r.data.data.some((b) => b.addons?.[0]?.staff?.full_name === 'Chi'), 'chủ studio thấy phân công trong danh sách đơn');
r = await call('PUT', `/studios/${sid}/staff/${an}`, owner, { role: 'makeup' });
ok(r.status === 400, 'không đổi vai trò người đã được phân công');

console.log('6. Hai set cùng giờ tranh 1 thợ (đồng thời)');
await call('PUT', `/studios/${sid}/staff/${chi}`, owner, { is_active: false });
r = await call('GET', `/studios/${sid}`, null);
ok(r.data.staff_counts.photographer === 1, 'Chi nghỉ → còn 1 thợ ảnh');
const reqs = [pkgA, pkgA, pkgB, pkgB].map((p) =>
  call('POST', '/bookings', khach, { package_id: p, start_time: iso(D2, '14:00'), num_people: 2, addon_ids: [PH] }));
const res = await Promise.all(reqs);
const codes = res.map((x) => x.status).sort();
ok(codes.filter((c) => c === 201).length === 1 && codes.filter((c) => c === 409).length === 3, `4 yêu cầu (2 set) cùng 14:00 + thợ ảnh → đúng 1 thành công: [${codes}]`);
const winner = res.find((x) => x.status === 201).data;

console.log('7. Từ chối đơn → trả lại thợ');
r = await call('GET', `/studios/${sid}/availability?date=${D2}&package_id=${pkgB}&addon_ids=${PH}`, null);
ok(!starts(r).includes('14:00'), 'trước khi từ chối: 14:00 + thợ ảnh không còn');
r = await call('PATCH', `/bookings/${winner.id}/status`, owner, { status: 'rejected', cancel_reason: 'test' });
ok(r.status === 200, 'từ chối đơn 14:00 (không cần phân công)');
r = await call('GET', `/studios/${sid}/availability?date=${D2}&package_id=${pkgB}&addon_ids=${PH}`, null);
ok(starts(r).includes('14:00'), 'sau khi từ chối: 14:00 + thợ ảnh hiện lại');

console.log(`\nKẾT QUẢ: ${pass} đạt, ${fail} lỗi`);
process.exit(fail ? 1 : 0);
