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

import psycopg2


def get_connection():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError("Thiếu biến môi trường DATABASE_URL")
    return psycopg2.connect(database_url)


def fetch_active_embeddings() -> list[dict]:
    """Lấy toàn bộ embedding của các Studio Set đang active, thuộc studio đã
    được duyệt (status='active'), kèm metadata cần thiết để trả về kết quả
    tìm kiếm mà không cần backend query lại lần nữa.
    """
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT ss.id, ss.studio_id, ss.name, s.name, ss.clip_embedding, ss.avatar_url
                FROM studio_sets ss
                JOIN studios s ON s.id = ss.studio_id
                WHERE ss.is_active = true
                  AND ss.clip_embedding IS NOT NULL
                  AND s.status = 'active'
                """
            )
            rows = cur.fetchall()
    finally:
        conn.close()

    results = []
    for set_id, studio_id, set_name, studio_name, embedding_raw, avatar_url in rows:
        # psycopg2 trả pgvector về dạng chuỗi "[0.1,0.2,...]" — tự parse thành list[float]
        vector = [float(x) for x in embedding_raw.strip("[]").split(",")]
        results.append(
            {
                "set_id": str(set_id),
                "studio_id": str(studio_id),
                "set_name": set_name,
                "studio_name": studio_name,
                "avatar_url": avatar_url,
                "vector": vector,
            }
        )
    return results


def save_embedding(set_id: str, vector: list[float]) -> None:
    """Lưu embedding vừa encode được vào cột clip_embedding của studio_sets.

    LƯU Ý: hàm này chưa được gọi ở đâu trong code hiện tại — để sẵn cho lúc
    xây Admin module (luồng: Admin duyệt studio -> backend gọi /encode cho
    từng Studio Set -> gọi hàm này lưu kết quả -> gọi /reindex). Chưa wiring
    vì Admin module chưa code.
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
