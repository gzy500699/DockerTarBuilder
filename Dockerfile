# =========================
# Build MinIO
# =========================
FROM golang:1.24.8-bookworm AS build

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

ARG MINIO_COMMIT=9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a

WORKDIR /src

RUN git init && \
    git remote add origin https://github.com/minio/minio && \
    git fetch --depth 1 origin ${MINIO_COMMIT} && \
    git checkout --detach FETCH_HEAD && \
    test "$(git rev-parse HEAD)" = "${MINIO_COMMIT}"

# 编译
RUN go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/minio \
    .


# =========================
# Generate source bundle
# =========================
FROM build AS source-bundle

RUN go mod vendor && \
    tar --exclude=.git \
        -czf /out/minio-corresponding-source.tar.gz \
        -C /src .


# =========================
# Export source archive
# =========================
FROM scratch AS source-export

COPY --from=source-bundle /out/minio-corresponding-source.tar.gz /


# =========================
# Runtime image
# =========================
FROM debian:bookworm-slim AS runtime

# 安装运行依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*


# 创建 minio 用户
RUN groupadd -g 10001 minio && \
    useradd -u 10001 -g minio -m minio


# 创建数据目录
RUN mkdir /data && \
    chown minio:minio /data


# 拷贝编译结果
COPY --from=build /out/minio /usr/local/bin/minio

# LICENSE
COPY --from=build /src/LICENSE /usr/share/license/minio/LICENSE


USER minio

WORKDIR /data

EXPOSE 9000 9001

ENTRYPOINT ["minio"]

CMD ["server", "/data", "--console-address", ":9001"]
