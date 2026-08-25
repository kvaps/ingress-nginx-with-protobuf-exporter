ARG TAG

FROM golang:1.24-alpine as builder
ARG TAG=$TAG
RUN apk add --no-cache git make bash
RUN git clone --branch controller-${TAG} --depth 1 https://github.com/kubernetes/ingress-nginx /src
WORKDIR /src
COPY patches/* .
RUN git apply *.diff
RUN make build DOCKER_IN_DOCKER_ENABLED=true ARCH=amd64
RUN apk add --no-cache libcap
RUN setcap cap_net_bind_service+ep /src/rootfs/bin/amd64/nginx-ingress-controller

FROM registry.k8s.io/ingress-nginx/controller:$TAG

USER root

# required packages to build lua and run luarocks. git is needed because the
# rockspecs below fetch their sources from git rather than a source tarball.
RUN apk add --no-cache make gcc musl-dev git

ARG LUA_ROCKS_VER="3.0.0"
RUN cd /tmp \
 && wget https://luarocks.org/releases/luarocks-${LUA_ROCKS_VER}.tar.gz \
 && tar zxf luarocks-${LUA_ROCKS_VER}.tar.gz \
 && cd luarocks-${LUA_ROCKS_VER} \
 && ./configure \
 && make build \
 && make install \
 && cd /tmp \
 && rm -rf /tmp/* \
 && mkdir -p /tmp/nginx && chown www-data: /tmp/nginx \
 && luarocks install https://luarocks.org/manifests/xavier-wang/lua-protobuf-0.4.1-1.rockspec \
 && luarocks install https://luarocks.org/manifests/lunarmodules/lua-iconv-7.1.0-1.rockspec

USER www-data

COPY --from=builder /src/rootfs/bin/amd64/nginx-ingress-controller /nginx-ingress-controller

COPY --chown=www-data:www-data ./etc/nginx /etc/nginx

LABEL org.opencontainers.image.source="https://github.com/cozystack/ingress-nginx-with-protobuf-exporter"
