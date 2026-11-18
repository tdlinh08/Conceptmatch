// Rà soát phía khách: email không phân biệt hoa thường, giới hạn 60 ngày, giờ máy chủ
// @chay-sau booking  (cần studio, bối cảnh, gói do bộ booking tạo)
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1';
let pass = 0, fail = 0;
const ok = (c, n, x = '') => { if (c) { pass++; console.log('  ✔', n); } else { fail++; console.log('  ✘', n, x); } };
async function call(m, p, t, b) {
  const r = await fetch(API + p, { method: m, headers: { ...(t && { Authorization: `Bearer ${t}` }), ...(b && { 'Content-Type': 'application/json' }) }, body: b ? JSON.stringify(b) : undefined });
  let d = null; try { d = await r.json(); } catch {}
  return { status: r.status, data: d };
}
let r = await call('POST', '/auth/register', null, { full_name: 'Hoa', email: '  Hoa.Nguyen@Test.com ', password: '12345678' });
ok(r.status === 201 && r.data.email === 'hoa.nguyen@test.com', 'đăng ký "Hoa.Nguyen@Test.com" -> lưu chữ thường', JSON.stringify(r.data));
r = await call('POST', '/auth/register', null, { full_name: 'Hoa 2', email: 'HOA.NGUYEN@test.com', password: '12345678' });
ok(r.status === 409, 'đăng ký lại cùng email khác hoa/thường -> 409');
r = await call('POST', '/auth/login', null, { email: 'Hoa.nguyen@TEST.com', password: '12345678' });
ok(r.status === 200 || r.status === 201, 'đăng nhập email viết hoa lung tung vẫn được', r.status);
const tok = r.data.access_token;
const s = (await call('GET', '/studios?limit=1', null)).data.data[0];
const det = (await call('GET', `/studios/${s.id}`, null)).data;
const pkg = det.sets.flatMap((x) => x.packages)[0];
r = await call('POST', '/bookings', tok, { package_id: pkg.id, start_time: '2027-03-01T09:00:00', num_people: 1 });
ok(r.status === 400 && /60 ngày/.test(r.data.message), 'đặt lịch quá 60 ngày -> 400', JSON.stringify(r.data));
console.log(`\nKẾT QUẢ: ${pass} đạt, ${fail} lỗi`);
process.exit(fail ? 1 : 0);
