// Chat + thông báo real-time: REST /conversations + Socket.IO
import { execSync } from 'node:child_process';
import { io } from 'socket.io-client';
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1'; const BASE = new URL(API).origin;
const sql = (q) => execSync(`psql "${process.env.TEST_DATABASE_URL}" -qtAc "${q}"`).toString().trim();
let pass = 0, fail = 0;
const ok = (c, n, x = '') => { if (c) { pass++; } else { fail++; console.log('  ✘', n, x); } };
const call = async (m, p, b, t) => { const r = await fetch(API + p, { method: m, headers: { 'Content-Type': 'application/json', ...(t && { Authorization: `Bearer ${t}` }) }, body: b ? JSON.stringify(b) : undefined }); let d = null; try { d = await r.json(); } catch {} return { s: r.status, d }; };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const reg = async (email, role = 'user') => { await call('POST', '/auth/register', { full_name: email.split('@')[0], email, password: 'Abcd@1234', role }); const r = await call('POST', '/auth/login', { email, password: 'Abcd@1234' }); return { t: r.d.access_token, id: r.d.user.id }; };
const connect = (token, useQuery = false) => new Promise((res) => {
  const ev = []; const s = io(BASE, { transports: ['websocket'], ...(useQuery ? { query: { token } } : { auth: { token } }), reconnection: false });
  s.onAny((e, p) => ev.push([e, p]));
  s.on('connect', () => setTimeout(() => res({ s, ev }), 150)); s.on('connect_error', () => res({ s, ev, err: true })); s.on('disconnect', () => ev.push(['__disconnect']));
});

const kh = await reg('chat_kh@t.test'); const kh2 = await reg('chat_kh2@t.test');
const cs = await reg('chat_cs@t.test', 'studio_owner'); const cs2 = await reg('chat_cs2@t.test', 'studio_owner');
const sid = sql(`insert into studios(id,owner_id,name,address,district,phone,status,updated_at) values (gen_random_uuid()::text,'${cs.id}','Studio Chat','1 Láng','Đống Đa','0900000000','active',now()) returning id`).split('\n')[0];
const sidPending = sql(`insert into studios(id,owner_id,name,address,district,phone,status,updated_at) values (gen_random_uuid()::text,'${cs.id}','Studio Chờ','2 Láng','Đống Đa','0900000001','pending',now()) returning id`).split('\n')[0];

// --- socket xác thực
const bad = await connect('abc');
await sleep(200);
ok(bad.ev.some(([e]) => e === 'auth_error') || bad.ev.some(([e]) => e === '__disconnect') || bad.err, 'socket: token sai bị từ chối');
const sKh = await connect(kh.t); const sCs = await connect(cs.t, true); const sKh2 = await connect(kh2.t);
ok(!sKh.err && sKh.s.connected, 'socket: khách kết nối bằng auth.token');
ok(!sCs.err && sCs.s.connected, 'socket: chủ studio kết nối bằng ?token=');

// --- tạo hội thoại
ok((await call('POST', '/conversations', { studio_id: sid }, cs.t)).s === 403, 'chủ studio không được tạo hội thoại (chỉ khách)');
ok((await call('POST', '/conversations', { studio_id: sidPending }, kh.t)).s === 404, 'studio chưa hoạt động -> 404');
ok((await call('POST', '/conversations', { studio_id: 'abc' }, kh.t)).s === 400, 'studio_id sai định dạng -> 400');
let r = await call('POST', '/conversations', { studio_id: sid }, kh.t);
ok(r.s === 201 && r.d.id && r.d.partner.name === 'Studio Chat' && r.d.my_role === 'customer' && r.d.unread === 0, 'khách mở hội thoại -> 201', JSON.stringify(r.d));
const cid = r.d.id;
r = await call('POST', '/conversations', { studio_id: sid }, kh.t);
ok(r.d.id === cid, 'bấm Nhắn tin lần 2 -> dùng lại hội thoại cũ');
ok((await call('GET', '/conversations', null, cs.t)).d.data.length === 0, 'hội thoại chưa có tin -> chủ studio chưa thấy');

// --- gửi tin qua REST
ok((await call('POST', `/conversations/${cid}/messages`, { content: '   ' }, kh.t)).s === 400, 'tin rỗng -> 400');
ok((await call('POST', `/conversations/${cid}/messages`, { content: 'x'.repeat(2001) }, kh.t)).s === 400, 'tin > 2000 ký tự -> 400');
ok((await call('POST', `/conversations/${cid}/messages`, { content: 'chen ngang' }, kh2.t)).s === 403, 'người ngoài gửi -> 403');
ok((await call('GET', `/conversations/${cid}/messages`, null, kh2.t)).s === 403, 'người ngoài đọc -> 403');
r = await call('POST', `/conversations/${cid}/messages`, { content: '  Chào studio, còn lịch thứ 7 không?  ' }, kh.t);
ok(r.s === 201 && r.d.content === 'Chào studio, còn lịch thứ 7 không?' && r.d.is_read === false, 'khách gửi tin -> 201, đã cắt khoảng trắng', JSON.stringify(r.d));
await sleep(300);
const got = (x, e) => x.ev.filter(([n]) => n === e).map(([, p]) => p);
ok(got(sCs, 'message_received').some((m) => m.conversation_id === cid && m.sender_id === kh.id), 'chủ studio nhận message_received real-time');
ok(got(sKh, 'message_received').length === 1, 'người gửi cũng nhận (đồng bộ thiết bị khác)');
ok(got(sKh2, 'message_received').length === 0, 'người ngoài không nhận');

// --- danh sách + chưa đọc
r = await call('GET', '/conversations', null, cs.t);
ok(r.d.data.length === 1 && r.d.data[0].unread === 1 && r.d.unread_total === 1 && r.d.data[0].partner.name === 'chat_kh' && r.d.data[0].my_role === 'owner', 'chủ studio thấy hội thoại, 1 tin chưa đọc', JSON.stringify(r.d));
ok((await call('GET', '/conversations/unread-count', null, cs.t)).d.unread_total === 1, 'unread-count chủ studio = 1');
ok((await call('GET', '/conversations/unread-count', null, kh.t)).d.unread_total === 0, 'unread-count khách = 0 (tin của chính mình)');
ok((await call('GET', '/conversations', null, cs2.t)).d.data.length === 0, 'chủ studio khác không thấy');

// --- mở hội thoại -> đã đọc + messages_read
r = await call('GET', `/conversations/${cid}/messages`, null, cs.t);
ok(r.s === 200 && r.d.data.length === 1 && r.d.total === 1, 'chủ studio tải tin nhắn');
await sleep(300);
ok((await call('GET', '/conversations/unread-count', null, cs.t)).d.unread_total === 0, 'mở hội thoại -> đánh dấu đã đọc');
ok(got(sKh, 'messages_read').some((p) => p.conversation_id === cid && p.reader_id === cs.id), 'khách nhận messages_read');

// --- gửi qua socket (ack)
const ack = await new Promise((res) => sCs.s.emit('send_message', { conversation_id: cid, content: 'Dạ còn ạ' }, res));
ok(ack && ack.ok === true && ack.message.content === 'Dạ còn ạ', 'chủ studio gửi qua socket, nhận ack', JSON.stringify(ack));
const ackBad = await new Promise((res) => sKh2.s.emit('send_message', { conversation_id: cid, content: 'xin chào' }, res));
ok(ackBad && ackBad.ok === false, 'người ngoài gửi qua socket -> ack lỗi');
await sleep(300);
ok(got(sKh, 'message_received').some((m) => m.content === 'Dạ còn ạ'), 'khách nhận tin của studio real-time');
ok((await call('GET', '/conversations/unread-count', null, kh.t)).d.unread_total === 1, 'khách có 1 tin chưa đọc');
r = await call('PATCH', `/conversations/${cid}/read`, null, kh.t);
ok(r.s === 200 && r.d.unread_total === 0, 'PATCH read -> 0 chưa đọc');

// --- phân trang, thứ tự
for (let i = 0; i < 5; i++) await call('POST', `/conversations/${cid}/messages`, { content: `tin ${i}` }, kh.t);
r = await call('GET', `/conversations/${cid}/messages?page=1&limit=3`, null, kh.t);
ok(r.d.data.length === 3 && r.d.total === 7 && r.d.data[0].content === 'tin 4', 'phân trang: mới nhất trước', JSON.stringify(r.d.data.map((m) => m.content)));
r = await call('GET', `/conversations/${cid}/messages?page=3&limit=3`, null, kh.t);
ok(r.d.data.length === 1 && r.d.data[0].content.startsWith('Chào studio'), 'trang cuối là tin đầu tiên');
ok((await call('GET', `/conversations`, null, kh.t)).d.data[0].last_message.content === 'tin 4', 'danh sách hiện tin cuối');

// --- thông báo real-time
sql(`select 1`);
const nBefore = got(sCs, 'notification_created').length;
// đổi trạng thái studio qua admin để sinh thông báo studio_approved cho chủ studio
const adm = (await call('POST', '/auth/login', { email: 'admin@t.test', password: 'Admin@123' })).d.access_token;
sql(`insert into studio_sets(id,studio_id,name,avatar_url) values (gen_random_uuid()::text,'${sidPending}','Set 1','/x.jpg')`);
const setId = sql(`select id from studio_sets where studio_id='${sidPending}'`);
sql(`insert into rental_packages(id,set_id,name,price,duration_minutes,max_people,updated_at) values (gen_random_uuid()::text,'${setId}','Gói',500000,60,5,now())`);
r = await call('PATCH', `/admin/studios/${sidPending}/approve`, {}, adm);
await sleep(400);
ok(r.s === 200 || r.s === 201, 'admin duyệt studio', JSON.stringify(r));
ok(got(sCs, 'notification_created').length === nBefore + 1 && got(sCs, 'notification_created').at(-1).type === 'studio_approved', 'chủ studio nhận notification_created real-time', JSON.stringify(got(sCs, 'notification_created')));

// --- tài khoản bị khoá không kết nối được
sql(`update users set status='locked' where id='${kh2.id}'`);
const locked = await connect(kh2.t); await sleep(200);
ok(locked.err || locked.ev.some(([e]) => e === 'auth_error' || e === '__disconnect'), 'tài khoản bị khoá -> socket bị từ chối');

for (const x of [sKh, sCs, sKh2, bad, locked]) x.s.close();
console.log(`KẾT QUẢ chat: ${pass} đạt, ${fail} lỗi`);
process.exit(0);
