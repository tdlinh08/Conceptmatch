// Báo cáo vi phạm + ẩn đánh giá
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1';
let pass = 0, fail = 0;
const ok = (c, n, x = '') => { if (c) { pass++; console.log('KẾT QUẢ ✔', n); } else { fail++; console.log('  ✘', n, x); } };
const call = async (m, p, t, b) => { const r = await fetch(API + p, { method: m, headers: { ...(t && { Authorization: `Bearer ${t}` }), ...(b && { 'Content-Type': 'application/json' }) }, body: b ? JSON.stringify(b) : undefined }); let d = null; try { d = await r.json(); } catch {} return { status: r.status, data: d }; };
const login = async (e, p) => (await call('POST', '/auth/login', null, { email: e, password: p })).data.access_token;
for (const [n, e, role] of [['Chủ BC', 'own18@t.test', 'studio_owner'], ['Khách A', 'ka18@t.test'], ['Khách B', 'kb18@t.test']])
  await call('POST', '/auth/register', null, { full_name: n, email: e, password: '12345678', ...(role && { role }) });
const owner = await login('own18@t.test', '12345678'), ka = await login('ka18@t.test', '12345678'), kb = await login('kb18@t.test', '12345678');
const admin = await login('admin@t.test', 'Admin@123');
const sid = (await call('POST', '/studios', owner, { name: 'Studio BC', address: '1', district: 'Ba Đình', phone: '0900000888' })).data.id;
const setId = (await call('POST', `/studios/${sid}/sets`, owner, { name: 'Set', capacity: 4, avatar_url: '/uploads/sets/a.jpg' })).data.id;
const pkg = (await call('POST', `/studios/${sid}/sets/${setId}/packages`, owner, { name: 'G', duration_minutes: 60, price: 200000, included_people: 2, max_people: 4 })).data.id;
await call('PATCH', `/admin/studios/${sid}/approve`, admin);
const rv = async (t, h, stars, comment) => {
  const id = (await call('POST', '/bookings', t, { package_id: pkg, start_time: `2026-12-22T${h}:00:00`, num_people: 2 })).data.id;
  for (const st of ['confirmed', 'checked_in', 'completed']) await call('PATCH', `/bookings/${id}/status`, owner, { status: st });
  return (await call('POST', '/reviews', t, { booking_id: id, stars, comment })).data.id;
};
const good = await rv(ka, '09', 5, 'Rất đẹp'), bad = await rv(kb, '11', 1, 'Studio lừa đảo, đồ tồi');
ok((await call('GET', `/studios/${sid}`, null)).data.avg_rating === 3, 'trước khi ẩn: điểm TB 3');

console.log('1. Gửi báo cáo');
let r = await call('POST', '/reports', owner, { target_type: 'review', target_id: bad, reason: 'Ngôn từ xúc phạm', detail: 'Khách không đến mà vẫn chê' });
ok(r.status === 201, 'chủ studio báo cáo đánh giá xấu', JSON.stringify(r.data));
ok((await call('POST', '/reports', owner, { target_type: 'review', target_id: bad, reason: 'x' })).status === 409, 'báo cáo trùng khi đang chờ -> 409');
ok((await call('POST', '/reports', kb, { target_type: 'review', target_id: bad, reason: 'x' })).status === 400, 'tự báo cáo đánh giá của mình -> 400');
ok((await call('POST', '/reports', owner, { target_type: 'studio', target_id: sid, reason: 'x' })).status === 400, 'chủ báo cáo studio của mình -> 400');
ok((await call('POST', '/reports', ka, { target_type: 'studio', target_id: sid, reason: 'Ảnh không đúng thực tế' })).status === 201, 'khách báo cáo studio');
ok((await call('POST', '/reports', kb, { target_type: 'studio', target_id: sid, reason: 'Thông tin sai sự thật' })).status === 201, 'khách thứ 2 báo cáo cùng studio');
ok((await call('POST', '/reports', admin, { target_type: 'studio', target_id: sid, reason: 'x' })).status === 403, 'admin không gửi báo cáo -> 403');
ok((await call('POST', '/reports', ka, { target_type: 'studio', target_id: sid })).status === 400, 'thiếu lý do -> 400');

console.log('2. Admin xử lý');
r = await call('GET', '/admin/reports?status=pending', admin);
ok(r.data.total === 3 && r.data.pending_count === 3, '3 báo cáo chờ');
const revRep = r.data.data.find((x) => x.target_type === 'review');
ok(revRep.review.comment === 'Studio lừa đảo, đồ tồi' && revRep.reporter.role === 'studio_owner', 'báo cáo kèm nội dung đánh giá + người báo cáo');
const stRep = r.data.data.find((x) => x.target_type === 'studio');
ok(stRep.reports_on_target === 2 && stRep.studio.name === 'Studio BC', 'đếm số lần nội dung bị báo cáo');
ok((await call('GET', '/admin/dashboard', admin)).data.pending_reports === 3, 'tổng quan: 3 báo cáo chờ');
ok((await call('PATCH', `/admin/reports/${revRep.id}/resolve`, admin, { action: 'take_down', note: 'x' })).status === 400, 'gỡ studio với báo cáo đánh giá -> 400');
r = await call('PATCH', `/admin/reports/${revRep.id}/resolve`, admin, { action: 'hide_review', note: 'Ngôn từ xúc phạm' });
ok(r.status === 200 && r.data.status === 'resolved', 'ẩn đánh giá qua báo cáo');
let d = (await call('GET', `/studios/${sid}`, null)).data;
ok(d.avg_rating === 5 && d.review_count === 1, 'đánh giá bị ẩn không tính điểm (TB 5, 1 đánh giá)', JSON.stringify([d.avg_rating, d.review_count]));
const pub = (await call('GET', `/studios/${sid}/reviews`, null)).data;
ok(pub.total === 1 && !pub.data.some((x) => x.id === bad), 'đánh giá bị ẩn không hiện công khai');
ok((await call('POST', '/reports', ka, { target_type: 'review', target_id: bad, reason: 'x' })).status === 404, 'không báo cáo được đánh giá đã ẩn');
r = await call('PATCH', `/admin/reports/${stRep.id}/dismiss`, admin, { note: 'Ảnh đúng thực tế' });
ok(r.status === 200 && r.data.closed === 2, 'bỏ qua -> đóng luôn cả 2 báo cáo cùng studio', JSON.stringify(r.data));
ok((await call('PATCH', `/admin/reports/${stRep.id}/dismiss`, admin, {})).status === 409, 'xử lý lại -> 409');
const nka = (await call('GET', '/notifications', ka)).data.data;
ok(nka.some((n) => n.type === 'report_handled' && /Ảnh đúng thực tế/.test(n.body)), 'người báo cáo nhận thông báo kết quả');
ok((await call('GET', '/admin/reports?status=pending', admin)).data.total === 0, 'hết báo cáo chờ');

console.log('3. Ẩn / hiện trực tiếp');
ok((await call('PATCH', `/admin/reviews/${good}/hide`, admin, {})).status === 400, 'ẩn thiếu lý do -> 400');
await call('PATCH', `/admin/reviews/${bad}/unhide`, admin);
d = (await call('GET', `/studios/${sid}`, null)).data;
ok(d.avg_rating === 3 && d.review_count === 2, 'hiện lại -> tính lại điểm');
const logs = (await call('GET', '/admin/audit-logs?target_type=review', admin)).data.data.map((x) => x.target_name + '|' + x.action);
ok(logs.some((l) => /Đánh giá 1★ của Khách B về Studio BC\|Hiện lại/.test(l)), 'nhật ký ghi tên đánh giá', JSON.stringify(logs));
ok((await call('GET', `/admin/users/${(await call('GET', '/admin/users?keyword=kb18', admin)).data.data[0].id}`, admin)).data.reviews[0].is_hidden === false, 'hồ sơ khách: đánh giá có cờ is_hidden');
ok((await call('GET', '/admin/reports', owner)).status === 403, 'chủ studio xem hàng chờ báo cáo -> 403');
console.log(`\nKẾT QUẢ: ${pass} đạt, ${fail} lỗi`);
