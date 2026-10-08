FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ARG ICEY_SERVER_BINARY=icey-server/build-dev/src/server/icey-server
ARG ICEY_WEB_ROOT=icey-server/web/dist
ARG ICEY_SAMPLE_MEDIA=icey/data/test.mp4
ARG ICEY_ENTRYPOINT=icey-server/docker/entrypoint.sh

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  ffmpeg \
  libssl3t64 \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --system --create-home --home-dir /home/icey --shell /usr/sbin/nologin icey

WORKDIR /app

RUN mkdir -p /app/media /app/recordings && chown -R icey:icey /app

COPY --chown=icey:icey --chmod=755 ${ICEY_SERVER_BINARY} /usr/local/bin/icey-server
COPY --chown=icey:icey ${ICEY_WEB_ROOT} /app/web
COPY --chown=icey:icey ${ICEY_SAMPLE_MEDIA} /app/media/test.mp4
COPY --chown=icey:icey ${ICEY_ENTRYPOINT} /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

EXPOSE 4500 3478/tcp 3478/udp

# /api/health is the unauthenticated liveness endpoint; a wedged-but-alive
# process fails this and gets restarted under restart policies.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${ICEY_PORT:-4500}/api/health" || exit 1

USER icey

ENTRYPOINT ["/app/entrypoint.sh"]
