ARG BUILD_FROM
FROM $BUILD_FROM

# Install mosquitto + auth plugin
WORKDIR /usr/src
ARG MOSQ_EXT_AUTH_VERSION
RUN apk add --no-cache \
    mosquitto \
    pwgen \
    && apk add --no-cache --virtual .build-dependencies \
    build-base \
    curl-dev \
    cjson-dev \
    git \
    mosquitto-dev \
    openssl-dev \
    cmake
RUN git clone --depth 1 -b "v${MOSQ_EXT_AUTH_VERSION}" https://github.com/Janrupf/mosq-ext-auth
WORKDIR /usr/src/mosq-ext-auth/build
RUN cmake .. -DCMAKE_BUILD_TYPE=Release
RUN cmake --build . --parallel
RUN mkdir -p /usr/share/mosquitto && cp libmosq_ext_auth.so /usr/share/mosquitto

WORKDIR /
RUN apk del --no-cache .build-dependencies
RUN rm -fr \
    /etc/logrotate.d \
    /etc/mosquitto/* \
    /etc/nginx/* \
    /usr/share/nginx \
    /usr/src/mosquitto-auth-plug \
    /var/lib/nginx/html \
    /var/www

# Copy rootfs
COPY rootfs /

