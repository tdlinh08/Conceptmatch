# ConceptMatch – AI Service

Dịch vụ tìm bối cảnh bằng hình ảnh: **CLIP ViT-B/32** (mã hoá ảnh thành vector 512 chiều, chuẩn hoá L2)
+ **FAISS IndexFlatIP** (tìm theo tích vô hướng = cosine). Vector lưu bền trong PostgreSQL (pgvector):
`studio_sets.clip_embedding` (ảnh đại diện) và `set_images.clip_embedding` (ảnh album).
Mỗi bối cảnh có nhiều vector (nhiều góc chụp); khi tìm, các vector cùng bối cảnh được gộp, lấy điểm cao nhất.

## Chạy trên Windows (không Docker)

Yêu cầu: Python **3.11** (khuyên dùng, giống Dockerfile), PostgreSQL đang chạy (cùng DB với backend).

```powershell
cd D:\conceptmatch\ai-service
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install torch --index-url https://download.pytorch.org/whl/cpu
pip install -r requirements.txt

# Cùng chuỗi kết nối với backend/.env (tham số ?schema=... được tự bỏ)
$env:DATABASE_URL = 'postgresql://postgres:MAT_KHAU@localhost:5432/conceptmatch?schema=public'
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Lần chạy đầu tải model từ Hugging Face (~600MB, cần Internet), các lần sau dùng bộ nhớ đệm.
Kiểm tra: mở `http://localhost:8000/health` → `{"status":"ok","indexed_sets":...,"indexed_images":...}`.
Backend cần `AI_SERVICE_URL=http://localhost:8000` trong `backend/.env`.

## API (backend gọi nội bộ)
| Method | Đường dẫn | Mô tả |
|---|---|---|
| GET | /health | Trạng thái + số bối cảnh / số ảnh trong chỉ mục |
| POST | /encode | `image` → vector 512 chiều |
| POST | /search | `image`, `top_k` → bối cảnh giống nhất (đã gộp theo bối cảnh) |
| POST | /reindex | Dựng lại chỉ mục FAISS từ Postgres |
