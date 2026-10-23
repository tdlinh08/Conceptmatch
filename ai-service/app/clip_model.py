"""
Quản lý model CLIP ViT-B/32 dùng để mã hoá ảnh thành vector embedding 512 chiều.

Dùng thư viện `transformers` (Hugging Face) thay vì package `clip` gốc của OpenAI,
vì `transformers` cài đặt đơn giản hơn nhiều (pip install thẳng, không cần clone
repo GitHub), trong khi vẫn dùng đúng weight gốc `openai/clip-vit-base-patch32`
như SRS đã chỉ định.
"""

import io
import threading

import torch
from PIL import Image
from transformers import CLIPModel, CLIPProcessor

MODEL_NAME = "openai/clip-vit-base-patch32"

_device = "cuda" if torch.cuda.is_available() else "cpu"
_model: CLIPModel | None = None
_processor: CLIPProcessor | None = None
_load_lock = threading.Lock()


def load_model() -> None:
    """Tải model vào RAM. Gọi 1 lần lúc FastAPI startup — KHÔNG gọi trong mỗi
    request, vì tải model mất vài giây, làm chậm request đầu tiên nếu load lazy.
    """
    global _model, _processor
    with _load_lock:
        if _model is None:
            print(f"[CLIP] Đang tải model {MODEL_NAME} (lần đầu sẽ tải về từ "
                  f"Hugging Face Hub, khoảng 350MB, các lần sau dùng cache)...")
            _model = CLIPModel.from_pretrained(MODEL_NAME).to(_device)
            _model.eval()  # tắt chế độ training (dropout, batchnorm...), chỉ dùng để suy luận
            _processor = CLIPProcessor.from_pretrained(MODEL_NAME)
            print(f"[CLIP] Đã tải xong model, chạy trên thiết bị: {_device}")


def encode_image_bytes(image_bytes: bytes) -> list[float]:
    """Nhận bytes của 1 ảnh, trả về vector embedding 512 chiều đã chuẩn hoá L2
    (unit vector) — chuẩn hoá để khi tìm kiếm bằng FAISS Inner Product, kết quả
    tương đương Cosine Similarity (công thức: cosine = dot product / (|a|*|b|),
    nếu |a|=|b|=1 thì cosine = dot product, tính bằng Inner Product luôn cho nhanh).
    """
    if _model is None or _processor is None:
        raise RuntimeError("Model CLIP chưa được load — gọi load_model() trước")

    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    inputs = _processor(images=image, return_tensors="pt").to(_device)

    with torch.no_grad():
        output = _model.get_image_features(**inputs)

    # Một số phiên bản `transformers` mới trả về object (ModelOutput) thay vì
    # tensor thẳng — kiểm tra và lấy đúng tensor embedding bên trong tuỳ trường hợp.
    if hasattr(output, "image_embeds"):
        features = output.image_embeds
    elif hasattr(output, "pooler_output"):
        features = output.pooler_output
    else:
        features = output

    normalized = features / features.norm(p=2, dim=-1, keepdim=True)
    return normalized[0].cpu().tolist()
