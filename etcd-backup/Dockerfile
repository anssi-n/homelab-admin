FROM gcr.io/etcd-development/etcd:v3.7.3 AS etcd

FROM alpine:latest

RUN apk add --no-cache \
    ca-certificates \
    aws-cli \
    age \
    zstd

COPY --from=etcd /usr/local/bin/etcdctl /usr/local/bin/etcdctl
COPY --from=etcd /usr/local/bin/etcdutl /usr/local/bin/etcdutl

RUN aws --version && etcdctl version && etcdutl version

ENTRYPOINT ["/bin/sh"]
