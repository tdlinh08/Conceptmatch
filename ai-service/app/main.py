from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from app import clip_model, db, faiss_index
from app.schemas import (
    EncodeResponse,
    HealthResponse,
    ReindexResponse,
    SearchResponse,
)

MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10MB — khớp giới hạn trong API Contract
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- Chạy lúc startup ---
    # Tải model CLIP ngay từ đầu (không đợi request đầu tiên), để tránh request
    # đầu tiên của người dùng bị chậm bất thường (vài giây) do phải tải model.
    clip_model.load_model()

    # Xây FAISS index từ dữ liệu đã có sẵn trong Postgres (nếu có)
    entries = db.fetch_active_embeddings()
    count = faiss_index.rebuild_index(entries)
    print(f"[Startup] Đã nạp {count} studio set vào FAISS index")

    yield
    # --- Chạy lúc shutdown (không cần dọn gì đặc biệt ở đây) ---


app = FastAPI(title="ConceptMatch AI Service", lifespan=lifespan)

# Cho phép NestJS backend (khác port/origin khi dev) gọi sang thoải mái.
# Trong môi trường thật, nên giới hạn allow_origins về đúng URL backend.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


async def _read_and_validate_image(image: UploadFile) -> bytes:
    if image.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Chỉ nhận JPG/PNG/WEBP")

    content = await image.read()
    if len(content) > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=413, detail="Ảnh tối đa 10MB")

    return content


@app.get("/health", response_model=HealthResponse)
def health():
    return HealthResponse(status="ok", indexed_sets=faiss_index.current_size())


@app.post("/encode", response_model=EncodeResponse)
async def encode(image: UploadFile = File(...)):
    """Dùng nội bộ: Backend gọi endpoint này để mã hoá ảnh đại diện của 1
    Studio Set thành embedding — dự kiến dùng trong luồng Admin duyệt studio
    (chưa wiring vì Admin module chưa code)."""
    content = await _read_and_validate_image(image)
    try:
        embedding = clip_model.encode_image_bytes(content)
    except Exception as e:  # noqa: BLE001 - trả lỗi rõ ràng cho client thay vì để crash
        raise HTTPException(status_code=500, detail=f"Lỗi xử lý ảnh: {e}")

    return EncodeResponse(embedding=embedding)


@app.post("/search", response_model=SearchResponse)
async def search(image: UploadFile = File(...), top_k: int = Form(10)):
    """Endpoint chính — tương ứng POST /ai/visual-search phía Backend.
    Backend forward nguyên ảnh moodboard người dùng upload sang đây."""
    content = await _read_and_validate_image(image)
    try:
        embedding = clip_model.encode_image_bytes(content)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Lỗi xử lý ảnh: {e}")

    results = faiss_index.search(embedding, top_k)
    return SearchResponse(results=results)


@app.post("/reindex", response_model=ReindexResponse)
def reindex():
    """Backend gọi endpoint này mỗi khi có Studio Set mới được thêm/encode
    xong, để FAISS index (đang chạy trong RAM) đồng bộ lại với Postgres."""
    entries = db.fetch_active_embeddings()
    count = faiss_index.rebuild_index(entries)
    return ReindexResponse(indexed_count=count)
