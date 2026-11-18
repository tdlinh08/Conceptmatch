// Thống kê admin + báo cáo doanh thu chủ studio
import { execSync } from 'node:child_process';
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1';
const sql = (q) => execSync(`psql "${process.env.TEST_DATABASE_URL}" -qtAc "${q}"`).toString().trim();
let pass = 0, fail = 0;
const ok = (c, n, x = '') => { if (c) { pass++; console.log('KẾT QUẢ ✔', n); } else { fail++; console.log('  ✘', n, x); } };
const call = async (m, p, t, b) => { const r = await fetch(API + p, { method: m, headers: { ...(t && { Authorization: `Bearer ${t}` }), ...(b && { 'Content-Type': 'application/json' }) }, body: b ? JSON.stringify(b) : undefined }); let d = null; try { d = await r.json(); } catch {} return { status: r.status, data: d }; };
const login = async (e, p) => (await call('POST', '/auth/login', null, { email: e, password: p })).data.access_token;
for (const [n, e, role] of [['Chủ TK', 'own15@t.test', 'studio_owner'], ['Chủ Khác', 'own16@t.test', 'studio_owner'], ['Khách TK', 'kh15@t.test', undefined]])
  await call('POST', '/auth/register', null, { full_name: n, email: e, password: '12345678', ...(role && { role }) });
const owner = await login('own15@t.test', '12345678'), other = await login('own16@t.test', '12345678');
const khach = await login('kh15@t.test', '12345678'), admin = await login('admin@t.test', 'Admin@123');
const mk = async (t, name, tag, district) => {
  const sid = (await call('POST', '/studios', t, { name, address: '1', district, phone: '0900000666' })).data.id;
  const setId = (await call('POST', `/studios/${sid}/sets`, t, { name: 'Set ' + tag, style_tag: tag, capacity: 4, avatar_url: '/uploads/sets/a.jpg' })).data.id;
  const pkg = (await call('POST', `/studios/${sid}/sets/${setId}/packages`, t, { name: 'G', duration_minutes: 60, price: 300000, included_people: 2, max_people: 4 })).data.id;
  await call('PATCH', `/admin/studios/${sid}/approve`, admin);
  return { sid, setId, pkg };
};
const A = await mk(owner, 'TK Một', 'vintage', 'Ba Đình');
const B = await mk(other, 'TK Hai', 'hàn quốc', 'Cầu Giấy');
const book = async (s, h) => (await call('POST', '/bookings', khach, { package_id: s.pkg, start_time: `2026-12-15T${h}:00:00`, num_people: 2 })).data.id;
const a1 = await book(A, '09'), a2 = await book(A, '11'), a3 = await book(A, '13'), b1 = await book(B, '09');
const done = async (t, id) => { for (const st of ['confirmed', 'checked_in', 'completed']) await call('PATCH', `/bookings/${id}/status`, t, { status: st }); };
await done(owner, a1); await done(owner, a2); await done(other, b1);
await call('PATCH', `/bookings/${a3}/status`, owner, { status: 'rejected', cancel_reason: 'Kín lịch' });
// Đưa buổi chụp về quá khứ để rơi vào kỳ thống kê:
// a1: 23:30 ngày 06/11 giờ VN (= 16:30 UTC 06/11) ; a2: 08:00 ngày 07/11 VN (= 01:00 UTC 07/11)
sql(`UPDATE bookings SET start_time='2026-11-06 16:30:00', end_time='2026-11-06 17:30:00' WHERE id='${a1}'`);
sql(`UPDATE bookings SET start_time='2026-11-07 01:00:00', end_time='2026-11-07 02:00:00' WHERE id='${a2}'`);
sql(`UPDATE bookings SET start_time='2026-11-07 02:00:00', end_time='2026-11-07 03:00:00' WHERE id='${b1}'`);

console.log('1. Chủ studio');
let r = await call('GET', '/stats/owner?range=30d', owner);
ok(r.status === 200 && r.data.series.length === 30, '30 ngày -> 30 cột', String(r.data?.series?.length));
const day = (k) => r.data.series.find((x) => x.key === k);
ok(day('2026-11-06')?.revenue === 300000 && day('2026-11-07')?.revenue === 300000, 'doanh thu gom theo ngày GIỜ VIỆT NAM (23:30 ngày 06 vẫn tính ngày 06)', JSON.stringify([day('2026-11-06'), day('2026-11-07')]));
ok(r.data.totals.revenue === 600000 && r.data.totals.bookings === 3 && r.data.totals.completed === 2, 'tổng: chỉ studio của mình (3 đơn, 2 hoàn thành, 600k)', JSON.stringify(r.data.totals));
ok(r.data.totals.lost_rate === 33.3 && r.data.totals.avg_order_value === 300000, 'tỉ lệ đơn mất 33,3% + giá trị TB/đơn');
ok(r.data.top_sets[0].name === 'Set vintage' && r.data.top_sets[0].bookings === 3 && r.data.top_sets[0].revenue === 600000, 'bối cảnh đặt nhiều nhất + doanh thu', JSON.stringify(r.data.top_sets));
ok(r.data.top_concepts[0].name === 'vintage' && !('new_users' in r.data.series[0]), 'concept; không lộ số người dùng mới cho chủ studio');
ok((await call('GET', `/stats/owner?studio_id=${B.sid}`, owner)).status === 403, 'xem studio người khác -> 403');
ok((await call('GET', `/stats/owner?studio_id=${A.sid}&range=7d`, owner)).data.series.length === 7, 'lọc 1 studio, 7 ngày');
r = await call('GET', '/stats/owner?range=12m', owner);
ok(r.data.series.length === 12 && r.data.series.find((x) => x.key === '2026-11').revenue === 600000, '12 tháng, gom theo tháng');
ok((await call('GET', '/stats/owner?range=1y', owner)).status === 400, 'range sai -> 400');
ok((await call('GET', '/stats/admin', owner)).status === 403, 'chủ studio gọi thống kê admin -> 403');

console.log('2. Admin');
r = await call('GET', '/stats/admin?range=30d', admin);
ok(r.status === 200 && r.data.totals.revenue === 900000 && r.data.totals.new_users >= 3, 'toàn sàn: doanh thu 900k, có người dùng mới', JSON.stringify(r.data.totals));
ok(r.data.top_studios[0].name === 'TK Một' && r.data.top_studios[0].revenue === 600000 && r.data.top_studios.length === 2, 'top studio theo doanh thu', JSON.stringify(r.data.top_studios));
ok(r.data.top_districts.some((d) => d.name === 'Cầu Giấy') && r.data.status_counts.completed === 3, 'theo quận + trạng thái');
console.log(`\nKẾT QUẢ: ${pass} đạt, ${fail} lỗi`);
