// Trang admin: danh sách / chi tiết studio, duyệt, từ chối, gỡ, khoá tài khoản, nhật ký, tổng quan
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1';
let pass = 0, fail = 0;
const ok = (c, n, x = '') => { if (c) { pass++; console.log('KẾT QUẢ ✔', n); } else { fail++; console.log('  ✘', n, x); } };
const call = async (m, p, t, b) => { const r = await fetch(API + p, { method: m, headers: { ...(t && { Authorization: `Bearer ${t}` }), ...(b && { 'Content-Type': 'application/json' }) }, body: b ? JSON.stringify(b) : undefined }); let d = null; try { d = await r.json(); } catch {} return { status: r.status, data: d }; };
const login = async (e, p) => (await call('POST', '/auth/login', null, { email: e, password: p })).data;
await call('POST', '/auth/register', null, { full_name: 'Chủ Ad', email: 'own14@t.test', password: '12345678', role: 'studio_owner' });
await call('POST', '/auth/register', null, { full_name: 'Khách Ad', email: 'kh14@t.test', password: '12345678' });
const owner = (await login('own14@t.test', '12345678')).access_token;
const admin = (await login('admin@t.test', 'Admin@123')).access_token;
const mk = async (name, withPkg = true) => {
  const sid = (await call('POST', '/studios', owner, { name, address: '9 Hàng Bài', district: 'Hoàn Kiếm', phone: '0900000555' })).data.id;
  if (withPkg) {
    const setId = (await call('POST', `/studios/${sid}/sets`, owner, { name: 'Set Ad', capacity: 4, avatar_url: '/uploads/sets/a.jpg' })).data.id;
    await call('POST', `/studios/${sid}/sets/${setId}/packages`, owner, { name: 'G', duration_minutes: 60, price: 200000, included_people: 2, max_people: 4 });
  }
  return sid;
};
const a = await mk('Admin Alpha'), b = await mk('Admin Beta'), c = await mk('Admin Chưa Gói', false);

console.log('1. Danh sách + chi tiết');
let r = await call('GET', '/admin/studios?status=pending&keyword=admin', admin);
ok(r.status === 200 && r.data.total === 3 && r.data.data[0].name === 'Admin Alpha', 'lọc chờ duyệt + từ khoá, cũ nhất lên đầu', JSON.stringify(r.data?.data?.map((x) => x.name)));
ok(r.data.data[0].owner.email === 'own14@t.test' && r.data.data[0].set_count === 1 && r.data.counts.pending >= 3, 'có chủ studio, số bối cảnh, số lượng theo trạng thái', JSON.stringify(r.data.counts));
ok((await call('GET', '/admin/studios?keyword=own14@t.test', admin)).data.total === 3, 'tìm theo email chủ studio');
ok((await call('GET', '/admin/studios?keyword=hang%20bai', admin)).data.total >= 3, 'tìm không dấu theo địa chỉ');
r = await call('GET', `/admin/studios/${a}`, admin);
ok(r.status === 200 && r.data.status === 'pending' && r.data.sets[0].packages.length === 1 && r.data.owner.full_name === 'Chủ Ad', 'chi tiết studio chờ duyệt (gói, chủ studio)');
ok((await call('GET', '/admin/studios', owner)).status === 403, 'chủ studio gọi API admin -> 403');
ok((await call('GET', '/admin/studios?status=abc', admin)).status === 400, 'status sai -> 400');

console.log('2. Duyệt / từ chối / gỡ');
ok((await call('PATCH', `/admin/studios/${c}/approve`, admin)).status === 400, 'studio chưa có gói -> không duyệt được');
ok((await call('PATCH', `/admin/studios/${a}/approve`, admin)).status === 200, 'duyệt studio');
r = await call('PATCH', `/admin/studios/${b}/reject`, admin, { reason: 'Ảnh chưa rõ' });
ok(r.status === 200 && r.data.status === 'rejected', 'từ chối studio');
ok((await call('PATCH', `/admin/studios/${b}/take-down`, admin, { reason: 'x' })).status === 409, 'gỡ studio không hoạt động -> 409');
r = await call('PATCH', `/admin/studios/${a}/take-down`, admin, { reason: 'Thông tin sai sự thật' });
ok(r.status === 200 && r.data.status === 'rejected', 'gỡ studio đang hoạt động', JSON.stringify(r.data));
ok((await call('GET', `/studios/${a}`, null)).status === 404, 'studio bị gỡ: khách không xem được nữa');
const notes = (await call('GET', '/notifications', owner)).data.data;
ok(notes.some((n) => n.title === 'Studio đã bị gỡ khỏi sàn' && /Thông tin sai sự thật/.test(n.body)), 'chủ studio nhận thông báo bị gỡ kèm lý do');
ok((await call('PATCH', `/admin/studios/${a}/take-down`, admin, {})).status === 400, 'gỡ thiếu lý do -> 400');

console.log('3. Khoá tài khoản');
const users = (await call('GET', '/admin/users?keyword=kh14', admin)).data.data;
const kid = users[0].id;
const kLogin = await login('kh14@t.test', '12345678');
ok((await call('PATCH', `/admin/users/${kid}/lock`, admin, { reason: 'Spam đặt lịch' })).status === 200, 'khoá tài khoản khách');
ok((await call('PATCH', `/admin/users/${kid}/lock`, admin, { reason: 'x' })).status === 409, 'khoá lại -> 409');
ok((await call('POST', '/auth/login', null, { email: 'kh14@t.test', password: '12345678' })).status !== 200, 'tài khoản bị khoá không đăng nhập được');
r = await call('POST', '/auth/refresh', null, { refresh_token: kLogin.refresh_token });
ok(r.status === 401 || r.status === 403, 'refresh token cũ bị thu hồi', String(r.status));
ok((await call('PATCH', `/admin/users/${kid}/unlock`, admin)).status === 200 && (await call('POST', '/auth/login', null, { email: 'kh14@t.test', password: '12345678' })).status === 200, 'mở khoá -> đăng nhập lại được');

console.log('4. Nhật ký + tổng quan');
r = await call('GET', '/admin/audit-logs?limit=10', admin);
const acts = r.data.data.map((x) => x.action);
ok(r.status === 200 && acts[0] === 'Mở khóa người dùng' && acts.includes('Gỡ studio') && acts.includes('Phê duyệt studio'), 'nhật ký mới nhất lên đầu', JSON.stringify(acts));
ok(r.data.data.find((x) => x.action === 'Gỡ studio').target_name === 'Admin Alpha', 'nhật ký có tên đối tượng');
ok((await call('GET', '/admin/audit-logs?target_type=user', admin)).data.data.every((x) => x.target_type === 'user'), 'lọc nhật ký theo loại');
r = await call('GET', '/admin/dashboard', admin);
ok(r.status === 200 && r.data.users_by_role.studio_owner >= 1 && typeof r.data.new_users_this_month === 'number' && r.data.bookings_this_month !== undefined, 'tổng quan có người dùng theo vai trò, đơn tháng này', JSON.stringify(r.data));
const cors = await fetch(new URL(API).origin + '/uploads/khong-co.jpg', { headers: { Origin: 'http://localhost:5555' } });
ok(cors.headers.get('access-control-allow-origin') !== null, 'file /uploads có header CORS (cho trang admin web)');
console.log(`\nKẾT QUẢ: ${pass} đạt, ${fail} lỗi`);
