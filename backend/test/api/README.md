# Kiểm thử API (end-to-end)

Các file `*.e2e.mjs` gọi API thật của backend (HTTP + Socket.IO) và kiểm tra kết quả.

| Bộ | Nội dung |
|---|---|
| booking | Đăng ký/đăng nhập, studio, bối cảnh, gói, giờ trống, đặt lịch, chống trùng, huỷ |
| staff-addons | Thợ ảnh/trang điểm, dịch vụ thêm, phân công thợ khi xác nhận |
| owner-bookings | Danh sách đơn của chủ studio |
| customer-rules | Email không phân biệt hoa thường, giới hạn đặt trước 60 ngày, giờ máy chủ |
| notifications | Thông báo trong app |
| chat | Nhắn tin REST + Socket.IO, đã đọc, thông báo real-time |
| forgot-password | Quên mật khẩu bằng mã 6 số |
| admin, admin-detail | Duyệt/từ chối/gỡ studio, khoá tài khoản, nhật ký |
| reports | Báo cáo vi phạm |
| stats | Thống kê |

## Cách chạy

1. Tạo CSDL kiểm thử riêng (tên phải có chữ `test`), ví dụ `conceptmatch_test`, rồi áp migration:
   `DATABASE_URL=postgresql://postgres:postgres123@localhost:5432/conceptmatch_test npx prisma migrate deploy`
2. Chạy backend trỏ vào CSDL đó, ghi log ra file (để bộ quên mật khẩu đọc được mã):
   `DATABASE_URL=...conceptmatch_test npm run start:prod > server.log`
3. Ở terminal khác:
   ```
   API_URL=http://localhost:3000/api/v1
   TEST_DATABASE_URL=postgresql://postgres:postgres123@localhost:5432/conceptmatch_test
   SERVER_LOG=./server.log
   npm run test:api
   ```

Cần có lệnh `psql` trong PATH. Trước mỗi bộ, script xoá sạch dữ liệu của CSDL kiểm thử.
