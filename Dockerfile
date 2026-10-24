FROM public-cn-beijing.cr.volces.com/public/base:python-3.10.6

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

RUN sed -i '/security/d; s#deb.debian.org#mirrors.aliyun.com#g' /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ffmpeg fonts-wqy-zenhei libgomp1 ca-certificates curl xz-utils openssl unzip \
 && rm -rf /var/lib/apt/lists/*

# 使用国内镜像安装 Node 20（抖音云构建环境无法直接拉取 Docker Hub 镜像）
RUN curl -fsSL https://npmmirror.com/mirrors/node/v20.19.0/node-v20.19.0-linux-x64.tar.xz -o /tmp/node.tar.xz \
 && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
 && rm -f /tmp/node.tar.xz \
 && node -v && npm -v

WORKDIR /app

COPY liuhe-server.zip /tmp/source.zip
RUN unzip -q /tmp/source.zip -d /app && rm -f /tmp/source.zip

RUN sed -i 's#https://registry.npmjs.org#https://registry.npmmirror.com#g' package-lock.json \
 && npm ci --omit=dev --registry=https://registry.npmmirror.com

RUN python3 -m venv /app/.venv \
 && /app/.venv/bin/pip install --no-cache-dir --upgrade pip -i https://mirrors.aliyun.com/pypi/simple/ \
 && /app/.venv/bin/pip install --no-cache-dir -i https://mirrors.aliyun.com/pypi/simple/ faster-whisper yt-dlp "opencv-python-headless==4.10.0.84" Pillow zhconv onnxruntime pypinyin jieba cn2an

# 不阻塞镜像构建下载 Whisper 模型；首次字幕任务运行时按需下载
RUN mkdir -p /app/models/hf /app/tmp/uploads /app/tmp/work /app/tmp/watermark /app/tmp/photo /app/tmp/voice /app/tmp/overlay /app/tmp/image-video

RUN mkdir -p /opt/application \
 && printf '%s\n' '#!/bin/sh' 'cd /app' 'export MEDIA_SIGNING_SECRET="${MEDIA_SIGNING_SECRET:-$(openssl rand -hex 32)}"' 'export AUTH_SECRET="${AUTH_SECRET:-$MEDIA_SIGNING_SECRET}"' 'exec node src/index.js' > /opt/application/run.sh \
 && chmod +x /opt/application/run.sh

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8000/api/health || exit 1

CMD ["node", "src/index.js"]
