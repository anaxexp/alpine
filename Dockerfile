ARG ALPINE_VER

FROM alpine:${ALPINE_VER}

ENV GOTPL_VER 0.1.5

RUN set -xe; \
    \
    apk add --update --no-cache \
        bash \
        ca-certificates \
        curl \
        gzip \
        tar \
        unzip \
        wget; \
        \
        gotpl_url="https://github.com/anaxexp/gotpl/releases/download/${GOTPL_VER}/gotpl-alpine-linux-amd64-${GOTPL_VER}.tar.gz"; \
        wget -qO- "${gotpl_url}" | tar xz -C /usr/local/bin; \
        \
    rm -rf /var/cache/apk/*
    
COPY ./bin/compare_semver /usr/local/bin/
COPY ./bin/exec_init_scripts /usr/local/bin/
COPY ./bin/gen_ssh_keys /usr/local/bin/
COPY ./bin/gen_ssl_certs /usr/local/bin/
COPY ./bin/get_archive /usr/local/bin/
COPY ./bin/gpg_verify /usr/local/bin/
COPY ./bin/wait_for /usr/local/bin/
