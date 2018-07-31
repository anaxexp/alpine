ARG ALPINE_VER

FROM alpine:${ALPINE_VER}

COPY bin/compare_semver /usr/local/bin/compare_semver
COPY bin/exec_init_scripts /usr/local/bin/exec_init_scripts
COPY bin/gen_ssh_keys /usr/local/bin/gen_ssh_keys
COPY bin/gen_ssl_certs /usr/local/bin/gen_ssl_certs
COPY bin/get_archive /usr/local/bin/get_archive
COPY bin/gpg_verify /usr/local/bin/gpg_verify
COPY bin/wait_for /usr/local/bin/wait_for

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
        chmod +x /usr/local/bin/compare_semver; \
        chmod +x /usr/local/bin/exec_init_scripts; \
        chmod +x /usr/local/bin/gen_ssh_keys; \
        chmod +x /usr/local/bin/gen_ssl_certs; \
        chmod +x /usr/local/bin/get_archive; \
        chmod +x /usr/local/bin/gpg_verify; \
        chmod +x /usr/local/bin/wait_for; \
        \
    rm -rf /var/cache/apk/*
    

