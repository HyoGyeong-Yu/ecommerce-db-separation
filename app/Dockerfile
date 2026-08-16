# ---------- 1단계: 빌드 (라이브러리 설치용) ----------
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
# --prefix로 별도 폴더에 설치 → 다음 단계에서 이 폴더만 복사
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- 2단계: 실행 (최종 이미지) ----------
FROM python:3.12-slim
WORKDIR /app

# 보안: root 대신 일반 유저 생성
RUN useradd --create-home --uid 1000 appuser

# 1단계에서 설치한 라이브러리만 가져옴 (pip 캐시, 빌드 찌꺼기 없음)
COPY --from=builder /install /usr/local

# 코드는 마지막에 복사 (자주 바뀌니까 → 캐시 최대 활용)
COPY main.py .

USER appuser
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
