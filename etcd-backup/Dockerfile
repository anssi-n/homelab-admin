ARG ETCD_VERSION=3.7.0-0
FROM registry.k8s.io/etcd:${ETCD_VERSION} AS etcd

FROM alpine:latest

RUN apk add --no-cache \
      ca-certificates \
      aws-cli \
      age \
      zstd \
      jq \
      curl \
      coreutils \
      tar \
      gzip \
 && aws --version \
 && jq --version \
 && etcdctl --version 2>/dev/null || true

COPY --from=etcd /usr/local/bin/etcd    /usr/local/bin/etcd
COPY --from=etcd /usr/local/bin/etcdctl /usr/local/bin/etcdctl
COPY --from=etcd /usr/local/bin/etcdutl /usr/local/bin/etcdutl

RUN etcd --version && etcdctl version && etcdutl version

ENV AWS_PAGER="" \
    AWS_EC2_METADATA_DISABLED=true \
    HOME=/tmp

ENTRYPOINT ["/bin/sh"]

