"""
AI Service kết nối trực tiếp tới CÙNG database Postgres mà NestJS backend dùng
(qua psycopg2, vì đây là Python — không dùng chung Prisma Client với backend).

Chỉ đọc/ghi đúng 1 cột: studio_sets.clip_embedding (kiểu vector(512) của
pgvector) — cột này Prisma không truy vấn được (khai báo Unsupported trong
schema.prisma), nên việc AI Service tự quản lý cột này qua SQL thô là hợp lý,
tách trách nhiệm rõ ràng: NestJS quản lý mọi thứ khác, AI Service chỉ động vào
đúng 1 cột liên quan tới máy học.
"""

import os
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import psycopg2

# Tham số chỉ Prisma hiểu (vd ?schema=public) — psycopg2/libpq sẽ báo lỗi
# "invalid URI query parameter" nếu để nguyên, nên bỏ đi trước khi kết nối.
_PRISMA_ONLY_PARAMS = {"schema", "connection_limit", "pool_timeout", "pgbouncer", "socket_timeout"}


def _libpq_url(url: str) -> str:
    parts = urlsplit(url)
    query = [(k, v) for k, v in parse_qsl(parts.query) if k not in _PRISMA_ONLY_PARAMS]
    return urlunsplit(parts._replace(query=urlencode(query)))


def get_connection():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError("Thiếu biến môi trường DATABASE_URL")
    return psycopg2.connect(_libpq_url(database_url))


def fetch_active_embeddings() -> list[dict]:
    """Lấy toàn bộ embedding của các Studio Set đang active, thuộc studio đã
    được duyệt (status='active'), kèm metadata cần thiết để trả về kết quả
    tìm kiếm mà không cần backend query lại lần nữa.
    """
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Mỗi bối cảnh có NHIỀU vector: ảnh đại diện + từng ảnh album (nhiều góc chụp).
            # Khi tìm, các vector cùng bối cảnh được gộp lại, lấy điểm cao nhất (xem faiss_index).
            cur.execute(
                """
                SELECT ss.id, ss.studio_id, ss.name, s.name, ss.clip_embedding::text,
                       ss.avatar_url, ss.avatar_url AS image_url
                FROM studio_sets ss
                JOIN studios s ON s.id = ss.studio_id
                WHERE ss.is_active = true AND ss.clip_embedding IS NOT NULL AND s.status = 'active'
                UNION ALL
                SELECT ss.id, ss.studio_id, ss.name, s.name, si.clip_embedding::text,
                       ss.avatar_url, si.url AS image_url
                FROM set_images si
                JOIN studio_sets ss ON ss.id = si.set_id
                JOIN studios s ON s.id = ss.studio_id
                WHERE ss.is_active = true AND si.clip_embedding IS NOT NULL AND s.status = 'active'
                """
            )
            rows = cur.fetchall()
    finally:
        conn.close()

    results = []
    for set_id, studio_id, set_name, studio_name, embedding_raw, avatar_url, image_url in rows:
        # pgvector trả về dạng chuỗi "[0.1,0.2,...]" — tự parse thành list[float]
        vector = [float(x) for x in embedding_raw.strip("[]").split(",")]
        results.append(
            {
                "set_id": str(set_id),
                "studio_id": str(studio_id),
                "set_name": set_name,
                "studio_name": studio_name,
                "avatar_url": avatar_url,
                "image_url": image_url,
                "vector": vector,
            }
        )
    return results


def save_embedding(set_id: str, vector: list[float]) -> None:
    """(Không dùng) Lưu embedding vào studio_sets.clip_embedding.
    Thực tế backend NestJS tự ghi cột vector sau khi gọi /encode (AiService.indexSets),
    giữ hàm này để tiện thử nghiệm thủ công.
    """
    vector_str = "[" + ",".join(str(x) for x in vector) + "]"
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE studio_sets SET clip_embedding = %s::vector WHERE id = %s",
                (vector_str, set_id),
            )
        conn.commit()
    finally:
        conn.close()
