FROM node:22-bookworm-slim

ENV NODE_ENV=production \
    PORT=8000 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/app/models/hf \
    BROWSER_RESOLVER=false \
    CHROME_NO_SANDBOX=true \
    WHISPER_MODEL=base \
    WHISPER_FOLLOW_MODEL=base \
    HF_ENDPOINT=https://hf-mirror.com \
    HF_HUB_DISABLE_XET=1 \
    PUBLIC_BASE_URL=https://1mhyvpewd0a2x-env-tYry4UbYVy.service.douyincloud.run \
    DOUYIN_APPID=tt52f92444cc87e3cf01

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-venv ffmpeg fonts-wqy-zenhei libgomp1 ca-certificates curl unzip openssl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY source.zip /tmp/source.zip
RUN unzip -q /tmp/source.zip -d /app && rm -f /tmp/source.zip

RUN npm ci --omit=dev

RUN python3 -m venv /app/.venv \
 && /app/.venv/bin/pip install --no-cache-dir --upgrade pip \
 && /app/.venv/bin/pip install --no-cache-dir faster-whisper yt-dlp "opencv-python-headless==4.10.0.84" Pillow zhconv onnxruntime pypinyin jieba cn2an

# 预下载 Whisper base，避免抖音云冷启动时下载模型失败
RUN mkdir -p /app/models/hf /app/tmp/uploads /app/tmp/work /app/tmp/watermark /app/tmp/photo /app/tmp/voice /app/tmp/overlay /app/tmp/image-video \
 && HF_HUB_DISABLE_XET=1 HF_ENDPOINT=https://hf-mirror.com /app/.venv/bin/python -c "from faster_whisper import WhisperModel; WhisperModel('base', device='cpu', compute_type='int8')"

RUN mkdir -p /opt/application \
 && printf '%s\n' '#!/bin/sh' 'cd /app' 'export MEDIA_SIGNING_SECRET="${MEDIA_SIGNING_SECRET:-$(openssl rand -hex 32)}"' 'export AUTH_SECRET="${AUTH_SECRET:-$MEDIA_SIGNING_SECRET}"' 'exec node src/index.js' > /opt/application/run.sh \
 && chmod +x /opt/application/run.sh

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8000/api/health || exit 1

CMD ["node", "src/index.js"]
