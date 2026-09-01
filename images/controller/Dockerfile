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

# lua-protobuf needs -fno-strict-aliasing. pb.c violates strict aliasing, gcc 13
# did not act on it and gcc 14 at -O2 does, and the pb.so that comes out makes
# nginx's cache manager and cache loader children segfault continuously, tens per
# second and indefinitely. The workers are unaffected, so the pod stays Ready
# with no restarts and the failure is invisible. Alpine 3.21 is where gcc 14
# arrived, and this base carries it.
#
# -O1 and -O0 also produce working modules, which is what points at the source
# rather than at the compiler version. lua-iconv is unaffected and keeps the
# default flags. The durable fix belongs upstream in lua-protobuf.
#
# The rocks get their own stage, on the same base as the runtime image so the
# LuaJIT and musl they compile against are identical by construction. It also
# keeps apk out of the runtime image, where installing musl-dev upgrades musl
# underneath the nginx that base image already built.
FROM registry.k8s.io/ingress-nginx/controller:$TAG as rocks

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
 && luarocks install https://luarocks.org/manifests/xavier-wang/lua-protobuf-0.4.1-1.rockspec CFLAGS="-O2 -fPIC -fno-strict-aliasing" \
 && luarocks install https://luarocks.org/manifests/lunarmodules/lua-iconv-7.1.0-1.rockspec

FROM registry.k8s.io/ingress-nginx/controller:$TAG

USER root

RUN mkdir -p /tmp/nginx && chown www-data: /tmp/nginx

USER www-data

# pb.so also answers require("pb.buffer") through Lua's all-in-one C loader, and
# protoc.lua is the pure-Lua half of lua-protobuf. pbmetrics.lua requires all
# three, plus iconv.
COPY --from=rocks /usr/local/lib/lua/5.1/pb.so /usr/local/lib/lua/5.1/pb.so
COPY --from=rocks /usr/local/lib/lua/5.1/iconv.so /usr/local/lib/lua/5.1/iconv.so
COPY --from=rocks /usr/local/share/lua/5.1/protoc.lua /usr/local/share/lua/5.1/protoc.lua

# Build-time smoke test, and the one a miscompiled pb.so fails. Loading protoc
# runs enough of pb.so's own code to hit the aliasing bug, and the process then
# dies with SIGSEGV on exit, so a bad build fails here instead of shipping an
# image that segfaults nginx's cache children in production.
RUN luajit -e 'require "protoc"; require "iconv"'

COPY --from=builder /src/rootfs/bin/amd64/nginx-ingress-controller /nginx-ingress-controller

COPY --chown=www-data:www-data ./etc/nginx /etc/nginx

LABEL org.opencontainers.image.source="https://github.com/cozystack/ingress-nginx-with-protobuf-exporter"
