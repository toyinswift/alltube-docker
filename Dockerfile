ARG ALPINE="alpine:3.19"

# ---------------------------
# Composer stage
# ---------------------------
FROM ${ALPINE} AS composer
RUN apk add --no-cache php82 php82-json php82-phar php82-mbstring php82-openssl curl
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# ---------------------------
# yt-dlp stage (HARDCODED LATEST)
# ---------------------------
FROM ${ALPINE} AS yt-dlp
ENV YTDLP_VERSION="2026.01.31"
RUN apk add --no-cache python3 curl
RUN curl -L \
    https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp \
    -o /usr/bin/yt-dlp
RUN chmod +x /usr/bin/yt-dlp

# ---------------------------
# Alltube stage (latest existing)
# ---------------------------
FROM ${ALPINE} AS alltube
RUN apk add --no-cache \
    php82 php82-dom php82-gmp php82-xml php82-intl php82-json \
    php82-phar php82-gettext php82-openssl php82-mbstring \
    php82-simplexml php82-tokenizer php82-xmlwriter \
    curl tar patch git

ENV ALLTUBE="3.2.0-alpha"

RUN curl -L \
    https://github.com/Rudloff/alltube/archive/refs/tags/${ALLTUBE}.tar.gz \
    | tar xz

WORKDIR /alltube-${ALLTUBE}/

COPY --from=composer /usr/bin/composer /usr/bin/composer
RUN composer install --no-interaction --optimize-autoloader --no-dev
RUN mv ./config/config.example.yml ./config/config.yml

COPY ./attach.css /tmp/
RUN cat /tmp/attach.css >> ./css/style.css
RUN chmod 777 ./templates_c/
RUN mv $(pwd) /alltube/

# ---------------------------
# Build stage
# ---------------------------
FROM ${ALPINE} AS build
RUN apk add --no-cache php82-fpm

WORKDIR /release/usr/bin/
RUN ln -s /usr/bin/python3 python

WORKDIR /release/etc/php82/php-fpm.d/
RUN sed 's?127.0.0.1:9000?/run/php-fpm.sock?' /etc/php82/php-fpm.d/www.conf > www.conf

COPY --from=alltube /alltube/ /release/var/www/alltube/
COPY --from=yt-dlp /usr/bin/yt-dlp /release/usr/bin/
COPY ./init.sh /release/usr/bin/alltube
COPY ./nginx/ /release/etc/nginx/

# ---------------------------
# Final runtime image
# ---------------------------
FROM ${ALPINE}
RUN apk add --no-cache \
    nginx ffmpeg python3 \
    php82 php82-dom php82-fpm php82-gmp php82-xml php82-intl php82-json \
    php82-gettext php82-openssl php82-mbstring php82-simplexml \
    php82-tokenizer php82-xmlwriter

COPY --from=build /release/ /

EXPOSE 80
ENTRYPOINT ["alltube"]
