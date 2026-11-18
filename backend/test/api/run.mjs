// Chạy bộ kiểm thử API (end-to-end) trên một server backend ĐANG CHẠY.
//
//   API_URL=http://localhost:3000/api/v1 \
//   TEST_DATABASE_URL=postgresql://postgres:postgres123@localhost:5432/conceptmatch_test \
//   SERVER_LOG=./server.log \
//   npm run test:api                 # chạy tất cả
//   npm run test:api -- chat booking # chỉ chạy vài bộ
//
// Mỗi bộ chạy trên CSDL trống: trước mỗi bộ, script XOÁ SẠCH dữ liệu các bảng rồi tạo
// lại tài khoản admin@t.test / Admin@123. Vì vậy TEST_DATABASE_URL BẮT BUỘC là CSDL
// kiểm thử riêng (tên có chữ "test" hoặc "e2e"), tuyệt đối không dùng CSDL thật.
import { execFileSync, spawnSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const bcrypt = require('bcrypt');

const DB = process.env.TEST_DATABASE_URL;
if (!DB) {
  console.error('Thiếu TEST_DATABASE_URL (CSDL kiểm thử riêng).');
  process.exit(1);
}
const dbName = new URL(DB).pathname.slice(1);
if (!/test|e2e/i.test(dbName)) {
  console.error(`Từ chối chạy: CSDL "${dbName}" không có chữ "test"/"e2e" trong tên — có thể là CSDL thật.`);
  process.exit(1);
}

const psql = (q) => execFileSync('psql', [DB, '-qtAc', q]).toString().trim();

function resetDatabase() {
  const tables = psql(
    "select string_agg(format('%I', tablename), ',') from pg_tables where schemaname='public' and tablename <> '_prisma_migrations'",
  );
  if (tables) psql(`TRUNCATE ${tables} CASCADE`);
  const hash = bcrypt.hashSync('Admin@123', 10);
  psql(
    `INSERT INTO users(id,full_name,email,password_hash,role,updated_at) VALUES (gen_random_uuid()::text,'Admin','admin@t.test','${hash}','admin',now())`,
  );
}

const wanted = process.argv.slice(2);
const suites = readdirSync(here)
  .filter((f) => f.endsWith('.e2e.mjs'))
  .filter((f) => wanted.length === 0 || wanted.some((w) => f.startsWith(w)))
  .sort();

let pass = 0;
let fail = 0;
for (const file of suites) {
  if (file.startsWith('forgot-password') && !process.env.SERVER_LOG) {
    console.log(`– ${file}: bỏ qua (cần SERVER_LOG để đọc mã gửi qua email)`);
    continue;
  }
  resetDatabase();
  // Bộ ghi "@chay-sau <tên>" ở đầu file cần dữ liệu do bộ khác tạo -> chạy bộ đó trước (bỏ qua kết quả)
  const dep = readFileSync(join(here, file), 'utf8').match(/@chay-sau (\S+)/)?.[1];
  if (dep) spawnSync(process.execPath, [join(here, `${dep}.e2e.mjs`)], { encoding: 'utf8', env: process.env });
  const r = spawnSync(process.execPath, [join(here, file)], { encoding: 'utf8', env: process.env });
  const out = `${r.stdout}${r.stderr}`;
  const m = out.match(/(\d+) đạt, (\d+) lỗi/);
  const p = m ? Number(m[1]) : 0;
  const f = m ? Number(m[2]) : 1;
  pass += p;
  fail += f;
  console.log(`${f === 0 ? '✔' : '✘'} ${file}: ${p} đạt, ${f} lỗi`);
  for (const line of out.split('\n')) if (line.includes('✘') || /Error/.test(line)) console.log('   ', line.trim());
}
console.log(`\nTỔNG: ${pass} ca đạt, ${fail} ca lỗi (${suites.length} bộ)`);
process.exit(fail === 0 ? 0 : 1);
