// Kiểm thử thông báo: đơn mới, xác nhận (kèm thợ), từ chối, huỷ, hoàn thành, đánh giá; đọc / đánh dấu đã đọc
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1';
let pass = 0, fail = 0;
const ok = (c, n, x = '') => { if (c) { pass++; console.log('  ✔', n); } else { fail++; console.log('  ✘', n, x); } };
async function call(m, p, t, b) {
  const r = await fetch(API + p, { method: m, headers: { ...(t && { Authorization: `Bearer ${t}` }), ...(b && { 'Content-Type': 'application/json' }) }, body: b ? JSON.stringify(b) : undefined });
  let d = null; try { d = await r.json(); } catch {}
  return { status: r.status, data: d };
}
const login = async (e, p) => (await call('POST', '/auth/login', null, { email: e, password: p })).data.access_token;
await call('POST', '/auth/register', null, { full_name: 'Chủ N', email: 'owner4@t.test', password: '12345678', role: 'studio_owner' });
await call('POST', '/auth/register', null, { full_name: 'Khách Nam', email: 'khach4@t.test', password: '12345678' });
const owner = await login('owner4@t.test', '12345678');
const khach = await login('khach4@t.test', '12345678');
const admin = await login('admin@t.test', 'Admin@123');
const sid = (await call('POST', '/studios', owner, { name: 'Studio Chuông', address: '1 A', district: 'Ba Đình', phone: '0900000100' })).data.id;
const setId = (await call('POST', `/studios/${sid}/sets`, owner, { name: 'Set Sáng', capacity: 4, avatar_url: 'https://e.com/a.jpg' })).data.id;
const pkg = (await call('POST', `/studios/${sid}/sets/${setId}/packages`, owner, { name: 'Gói 1 giờ', duration_minutes: 60, price: 200000, included_people: 2, max_people: 4 })).data.id;
const minh = (await call('POST', `/studios/${sid}/staff`, owner, { full_name: 'Minh', role: 'photographer' })).data.id;
const ph = (await call('POST', `/studios/${sid}/addons`, owner, { role: 'photographer', name: 'Thợ ảnh', price: 100000, unit: 'per_booking' })).data.id;
await call('PATCH', `/admin/studios/${sid}/approve`, admin);

const D = '2026-11-20';
const list = async (t) => (await call('GET', '/notifications', t)).data;

console.log('1. Duyệt studio + đơn mới');
let n = await list(owner);
ok(n.data.some((x) => x.type === 'studio_approved') && n.unread === 1, 'chủ studio nhận "Studio đã được phê duyệt"', JSON.stringify(n));
const b1 = (await call('POST', '/bookings', khach, { package_id: pkg, start_time: `${D}T09:00:00`, num_people: 2, addon_ids: [ph] })).data.id;
n = await list(owner);
const nb = n.data.find((x) => x.type === 'booking_new');
ok(nb && nb.ref_id === b1 && /Khách Nam đặt Set Sáng · Gói 1 giờ lúc 09:00 20\/11 · kèm Thợ ảnh/.test(nb.body), 'đơn mới: báo chủ studio đủ khách, set, gói, giờ, dịch vụ', nb?.body);
ok((await call('GET', '/notifications/unread-count', owner)).data.unread === 2, 'chủ studio: 2 chưa đọc');

console.log('2. Xác nhận / từ chối / huỷ / hoàn thành');
await call('PATCH', `/bookings/${b1}/status`, owner, { status: 'confirmed', staff_assignments: [{ role: 'photographer', staff_id: minh }] });
n = await list(khach);
const nc = n.data.find((x) => x.type === 'booking_confirmed');
ok(nc && /Thợ ảnh: Minh/.test(nc.body) && nc.ref_id === b1, 'khách: "đã xác nhận lịch" kèm tên thợ', nc?.body);
const b2 = (await call('POST', '/bookings', khach, { package_id: pkg, start_time: `${D}T11:00:00`, num_people: 2 })).data.id;
await call('PATCH', `/bookings/${b2}/status`, owner, { status: 'rejected', cancel_reason: 'Studio bảo trì' });
n = await list(khach);
ok(n.data.some((x) => x.type === 'booking_rejected' && /Studio bảo trì/.test(x.body)), 'khách: "đã từ chối" kèm lý do');
const b3 = (await call('POST', '/bookings', khach, { package_id: pkg, start_time: `${D}T13:00:00`, num_people: 2 })).data.id;
await call('DELETE', `/bookings/${b3}`, khach);
n = await list(owner);
ok(n.data.some((x) => x.type === 'booking_cancelled' && /Khách Nam đã huỷ/.test(x.body)), 'chủ studio: "khách huỷ lịch"');
await call('PATCH', `/bookings/${b1}/status`, owner, { status: 'checked_in' });
await call('PATCH', `/bookings/${b1}/status`, owner, { status: 'completed' });
n = await list(khach);
ok(n.data.some((x) => x.type === 'booking_completed'), 'khách: "buổi chụp đã hoàn thành" mời đánh giá');
ok(n.data.filter((x) => x.ref_id === b1).length === 2, 'check-in không tạo thông báo thừa (đơn 1 chỉ có xác nhận + hoàn thành)');

console.log('3. Đánh giá');
await call('POST', '/reviews', khach, { booking_id: b1, stars: 5, comment: 'Ánh sáng rất đẹp' });
n = await list(owner);
ok(n.data.some((x) => x.type === 'review_new' && /Ánh sáng rất đẹp/.test(x.body)), 'chủ studio: "Đánh giá mới ★★★★★"');

console.log('4. Đọc thông báo');
n = await list(khach);
const before = n.unread;
const one = n.data[0];
let r = await call('PATCH', `/notifications/${one.id}/read`, khach);
ok(r.status === 200 && r.data.unread === before - 1, `đánh dấu 1 cái đã đọc: ${before} → ${before - 1}`);
r = await call('PATCH', `/notifications/${one.id}/read`, owner);
ok(r.status === 404, 'không đánh dấu được thông báo của người khác');
r = await call('PATCH', '/notifications/read-all', khach);
ok((await call('GET', '/notifications/unread-count', khach)).data.unread === 0, 'đọc tất cả → 0');
ok((await call('GET', '/notifications', null)).status === 401, 'chưa đăng nhập → 401');
n = await list(khach);
ok(new Date(n.data[0].created_at) >= new Date(n.data[n.data.length - 1].created_at), 'mới nhất lên đầu');

console.log(`\nKẾT QUẢ: ${pass} đạt, ${fail} lỗi`);
process.exit(fail ? 1 : 0);
