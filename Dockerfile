ARG DEBIAN_FRONTEND=noninteractive
FROM debian:12.13-slim@sha256:56ff6d36d4eb3db13a741b342ec466f121480b5edded42e4b7ee850ce7a418ee AS builder

# Install dependencies and compile
RUN apt-get update \
    && apt-get --no-install-recommends --yes install \
    git \
    build-essential \
    ca-certificates \
    cmake \
    libicu-dev \
    libpcre3-dev \
    libssl-dev \
    libmaxminddb-dev \
    gettext \
    libasprintf-dev \
    mariadb-server \
    libmariadb-dev \
    mariadb-client \
    python3 \
    libmariadb-dev-compat

# icu
# RUN git clone --depth 1 --branch release-72-1 https://github.com/unicode-org/icu.git \
#     && cd icu/icu4c/source \
#     && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./runConfigureICU Linux --enable-shared \
#     && make \
#     && make install

# Verlihub
# renovate: datasource=github-releases packageName=Verlihub/verlihub versioning=loose
ARG VERLIHUB_VERSION="1.6.0.0"
RUN mkdir -p /tmp/verlihub \
    && git clone --depth 1 --branch ${VERLIHUB_VERSION} https://github.com/Verlihub/verlihub.git \
    && mkdir -p verlihub/build \
    && cd verlihub/build \
    && cmake -DWITH_PLUGINS=OFF .. \
    && make \
    && make install DESTDIR=/tmp/verlihub

FROM debian:12.13-slim@sha256:56ff6d36d4eb3db13a741b342ec466f121480b5edded42e4b7ee850ce7a418ee
WORKDIR /opt/verlihub/

# Install s6-overlay installation dependencies
RUN apt-get update \
    && apt-get --no-install-recommends --yes install \
    xz-utils
WORKDIR /tmp/

# s6-overlay
# renovate: datasource=github-releases packageName=just-containers/s6-overlay versioning=loose
ARG S6_OVERLAY_VERSION="v3.2.2.0"
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz.sha256 /tmp
RUN echo "$(cat s6-overlay-noarch.tar.xz.sha256)" | sha256sum -c - \
    && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz.sha256 /tmp
RUN echo "$(cat s6-overlay-x86_64.tar.xz.sha256)" | sha256sum -c - \
    && tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
COPY s6-rc.d/ /etc/s6-overlay/s6-rc.d/

# Install runtime dependencies
RUN apt-get --no-install-recommends --yes install \
    libpcre3 \
    libmaxminddb0 \
    libicu72 \
    libasprintf0v5 \
    libmariadb3 \
    pip \
    && pip3 install --break-system-packages mysql-connector-python \
    && useradd --system --base-dir /opt verlihub \
    && mkdir -p /opt/verlihub/.config/verlihub/ \
    && chown -R verlihub:verlihub /opt/verlihub/

# Copy files from build image
COPY --from=builder /tmp/verlihub/ /

# Run ldconfig
RUN ldconfig

# Copy files to image
COPY --chmod=700 --chown=verlihub:verlihub scripts/setup.py /opt/verlihub/scripts/setup.py

# Set entrypoint
ENTRYPOINT ["/init"]

LABEL org.opencontainers.image.authors="MattKobayashi <matthew@kobayashi.au>"
