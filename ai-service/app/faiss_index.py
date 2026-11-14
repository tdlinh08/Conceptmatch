"""
Quản lý FAISS index trong RAM để tìm kiếm tương đồng nhanh.

THIẾT KẾ: embedding gốc được lưu bền vững trong Postgres (cột clip_embedding,
kiểu vector(512) của pgvector) — đó là "nguồn sự thật" (source of truth).
FAISS index ở đây chỉ là một bản sao trong RAM, tối ưu tốc độ tìm kiếm
(IndexFlatIP nhanh hơn nhiều so với truy vấn pgvector thô cho tập dữ liệu lớn,
dù với quy mô đồ án tốt nghiệp thì cả 2 cách đều đủ nhanh — dùng FAISS chủ yếu
để đúng với công nghệ đã cam kết trong SRS).

Index được xây lại toàn bộ (rebuild) mỗi khi có thay đổi, KHÔNG hỗ trợ thêm/xoá
từng phần tử lẻ — đơn giản hơn và đủ dùng vì tần suất Admin duyệt studio thấp.
"""

import threading

import faiss
import numpy as np

_lock = threading.Lock()
_index: faiss.IndexFlatIP | None = None
_metadata: list[dict] = []  # metadata[i] tương ứng với vector thứ i trong _index


def rebuild_index(entries: list[dict]) -> int:
    """Xây lại toàn bộ FAISS index từ danh sách entries (mỗi entry có key
    'vector' + metadata khác). Trả về số lượng đã index.
    """
    global _index, _metadata
    with _lock:
        if not entries:
            _index = None
            _metadata = []
            return 0

        dim = len(entries[0]["vector"])
        vectors = np.array([e["vector"] for e in entries], dtype="float32")

        new_index = faiss.IndexFlatIP(dim)
        new_index.add(vectors)

        _index = new_index
        _metadata = entries
        return len(entries)


def search(query_vector: list[float], top_k: int = 10) -> list[dict]:
    """Tìm top_k BỐI CẢNH giống nhất. Index chứa nhiều vector cho 1 bối cảnh (ảnh đại diện +
    album), nên lấy dư ứng viên rồi GỘP theo set_id, giữ ảnh có điểm cao nhất
    (max-pooling): bối cảnh khớp với BẤT KỲ góc chụp nào của nó đều được xếp hạng cao.
    """
    with _lock:
        if _index is None or _index.ntotal == 0:
            return []

        query = np.array([query_vector], dtype="float32")
        k = min(max(top_k * 8, 50), _index.ntotal)  # lấy dư để còn đủ top_k bối cảnh sau khi gộp
        scores, indices = _index.search(query, k)

        best: dict[str, dict] = {}
        for score, idx in zip(scores[0], indices[0]):
            if idx == -1:
                continue
            meta = _metadata[idx]
            set_id = meta["set_id"]
            if set_id in best:
                continue  # FAISS trả theo điểm giảm dần -> lần đầu gặp là điểm cao nhất của set
            best[set_id] = {
                "studio_id": meta["studio_id"],
                "studio_name": meta["studio_name"],
                "set_id": set_id,
                "set_name": meta["set_name"],
                "avatar_url": meta["avatar_url"],
                "matched_image_url": meta.get("image_url") or meta["avatar_url"],
                "similarity_score": float(score),
            }
            if len(best) >= top_k:
                break
        return list(best.values())


def current_size() -> int:
    """Số vector (ảnh) đang có trong index."""
    return _index.ntotal if _index is not None else 0


def current_sets() -> int:
    """Số bối cảnh khác nhau đang có trong index."""
    return len({m["set_id"] for m in _metadata})
