FROM python:3.11-slim

WORKDIR /app

# libpq-dev: cần để build psycopg2 (kết nối Postgres)
# gcc: cần để build 1 số package Python có phần C extension
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

# Cài torch bản CPU-only TRƯỚC, riêng biệt khỏi requirements.txt.
# Lý do: bản mặc định trên PyPI kèm theo hỗ trợ GPU (CUDA), nặng hơn nhiều lần
# (~2-4GB) so với bản CPU-only (~200MB) — đồ án không cần GPU, dùng bản CPU đủ
# nhanh cho việc encode ảnh đơn lẻ.
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
