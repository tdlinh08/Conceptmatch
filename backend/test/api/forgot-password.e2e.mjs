// Quên mật khẩu: POST /auth/forgot-password, POST /auth/reset-password (SMTP chưa cấu hình -> mã in ra log)
import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1';
const LOG = process.env.SERVER_LOG; // file log của server đang chạy (mã quên mật khẩu được in ra đây khi chưa cấu hình SMTP)
const sql = (q) => execSync(`psql "${process.env.TEST_DATABASE_URL}" -qtAc "${q}"`).toString().trim();
let pass = 0, fail = 0;
const ok = (c, n, x = '') => { if (c) { pass++; } else { fail++; console.log('  ✘', n, x); } };
const call = async (m, p, b, t) => { const r = await fetch(API + p, { method: m, headers: { 'Content-Type': 'application/json', ...(t && { Authorization: `Bearer ${t}` }) }, body: b ? JSON.stringify(b) : undefined }); let d = null; try { d = await r.json(); } catch {} return { s: r.status, d }; };
const codes = () => [...readFileSync(LOG, 'utf8').matchAll(/của bạn là: (\d{6})/g)].map((m) => m[1]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const E = 'quenmk@t.test';
await call('POST', '/auth/register', { full_name: 'Quên MK', email: E, password: 'MatKhauCu1' });
const login1 = await call('POST', '/auth/login', { email: E, password: 'MatKhauCu1' });
ok(login1.s === 200, 'đăng nhập mật khẩu cũ');
const oldRefresh = login1.d.refresh_token;

// 1. email tồn tại -> 200 + mã trong log
let r = await call('POST', '/auth/forgot-password', { email: '  QuenMK@T.test ' });
await sleep(300);
ok(r.s === 200 && /Nếu email đã đăng ký/.test(r.d.message), 'forgot: 200, thông báo chung', JSON.stringify(r));
ok(codes().length === 1, 'forgot: có đúng 1 mã (email không phân biệt hoa thường)', codes().length);
ok(/EMAIL CHƯA GỬI THẬT/.test(readFileSync(LOG, 'utf8')), 'chưa có SMTP -> in email ra log');
const code1 = codes()[0];
// 2. email không tồn tại -> cùng thông báo, không có mã
r = await call('POST', '/auth/forgot-password', { email: 'khongco@t.test' });
await sleep(200);
ok(r.s === 200 && /Nếu email đã đăng ký/.test(r.d.message) && codes().length === 1, 'email không tồn tại: trả giống hệt, không tạo mã');
// 3. gửi lại trong 60 giây -> không tạo mã mới
r = await call('POST', '/auth/forgot-password', { email: E });
await sleep(200);
ok(r.s === 200 && codes().length === 1 && sql(`select count(*) from password_resets`) === '1', 'gửi lại trong 60 giây: không tạo mã mới');
// 4. dữ liệu sai
ok((await call('POST', '/auth/forgot-password', { email: 'abc' })).s === 400, 'forgot email sai định dạng -> 400');
ok((await call('POST', '/auth/reset-password', { email: E, code: '12ab56', new_password: 'MatKhauMoi1' })).s === 400, 'mã không phải 6 số -> 400');
ok((await call('POST', '/auth/reset-password', { email: E, code: code1, new_password: 'ngan' })).s === 400, 'mật khẩu mới < 8 ký tự -> 400');
// 5. sai mã -> 400 còn 4 lần
const wrong = code1 === '000000' ? '111111' : '000000';
r = await call('POST', '/auth/reset-password', { email: E, code: wrong, new_password: 'MatKhauMoi1' });
ok(r.s === 400 && /còn 4 lần/.test(r.d.message), 'sai mã lần 1 -> còn 4 lần', JSON.stringify(r.d));
ok(sql(`select code_hash like '\\$2%' from password_resets limit 1`) === 't' && sql(`select count(*) from password_resets where code_hash = '${code1}'`) === '0', 'chỉ lưu bản băm của mã');
// 6. đúng mã -> đổi mật khẩu, thu hồi phiên
r = await call('POST', '/auth/reset-password', { email: E, code: code1, new_password: 'MatKhauMoi1' });
ok(r.s === 200 && /thành công/.test(r.d.message), 'đúng mã -> 200', JSON.stringify(r));
ok((await call('POST', '/auth/refresh', { refresh_token: oldRefresh })).s === 401, 'refresh token cũ bị thu hồi');
ok((await call('POST', '/auth/login', { email: E, password: 'MatKhauCu1' })).s === 401, 'mật khẩu cũ không còn dùng được');
ok((await call('POST', '/auth/login', { email: E, password: 'MatKhauMoi1' })).s === 200, 'đăng nhập bằng mật khẩu mới');
ok((await call('POST', '/auth/reset-password', { email: E, code: code1, new_password: 'MatKhauKhac1' })).s === 400, 'dùng lại mã đã dùng -> 400');
// 7. sai 5 lần -> mã bị huỷ (lùi created_at để qua thời gian chờ 60s)
sql(`update password_resets set created_at = now() - interval '2 minutes'`);
await call('POST', '/auth/forgot-password', { email: E });
await sleep(300);
const code2 = codes().at(-1);
ok(codes().length === 2 && code2, 'qua 60 giây -> nhận mã mới');
const w2 = code2 === '000000' ? '111111' : '000000';
let last;
for (let i = 0; i < 5; i++) last = await call('POST', '/auth/reset-password', { email: E, code: w2, new_password: 'MatKhauMoi2' });
ok(last.s === 400 && /quá 5 lần/.test(last.d.message), 'sai 5 lần -> báo yêu cầu mã mới', JSON.stringify(last.d));
ok((await call('POST', '/auth/reset-password', { email: E, code: code2, new_password: 'MatKhauMoi2' })).s === 400, 'sau 5 lần sai, mã đúng cũng không dùng được');
// 8. mã hết hạn
sql(`update password_resets set created_at = now() - interval '2 minutes'`);
await call('POST', '/auth/forgot-password', { email: E });
await sleep(300);
const code3 = codes().at(-1);
sql(`update password_resets set expires_at = now() - interval '1 minute' where used_at is null`);
ok((await call('POST', '/auth/reset-password', { email: E, code: code3, new_password: 'MatKhauMoi3' })).s === 400, 'mã hết hạn -> 400');
// 9. mã mới làm mã cũ chưa dùng mất hiệu lực
sql(`update password_resets set created_at = now() - interval '2 minutes', expires_at = now() + interval '10 minutes'`);
await call('POST', '/auth/forgot-password', { email: E });
await sleep(300);
const code4 = codes().at(-1);
ok((await call('POST', '/auth/reset-password', { email: E, code: code3, new_password: 'MatKhauMoi4' })).s === 400 || code3 === code4, 'mã cũ mất hiệu lực khi có mã mới');
ok((await call('POST', '/auth/reset-password', { email: E, code: code4, new_password: 'MatKhauMoi4' })).s === 200, 'mã mới nhất dùng được');
// 10. tài khoản bị khoá -> không gửi mã
sql(`update users set status = 'locked' where email = '${E}'`);
sql(`update password_resets set created_at = now() - interval '2 minutes'`);
const before = codes().length;
r = await call('POST', '/auth/forgot-password', { email: E });
await sleep(300);
ok(r.s === 200 && codes().length === before, 'tài khoản bị khoá: trả thông báo chung, không gửi mã');
console.log(`KẾT QUẢ: ${pass} đạt, ${fail} lỗi`);
