# -----------------------------------
# Base
# -----------------------------------
ARG ALPINE="alpine:3.20"

# -----------------------------------
# Composer stage
# -----------------------------------
FROM ${ALPINE} AS composer

RUN apk add --no-cache \
    php83 php83-phar php83-json php83-mbstring php83-openssl \
    curl

RUN curl -sS https://getcomposer.org/installer | php83 -- \
    --install-dir=/usr/local/bin \
    --filename=composer

# -----------------------------------
# yt-dlp stage (pip version)
# -----------------------------------
FROM ${ALPINE} AS yt-dlp

RUN apk add --no-cache python3 py3-pip

# Install latest yt-dlp from pip (more reliable for TikTok)
RUN pip3 install --no-cache-dir -U yt-dlp

# -----------------------------------
# AllTube stage
# -----------------------------------
FROM ${ALPINE} AS alltube

RUN apk add --no-cache \
    php83 php83-dom php83-gmp php83-xml php83-intl php83-json \
    php83-gettext php83-openssl php83-mbstring php83-simplexml \
    php83-tokenizer php83-xmlwriter php83-phar \
    curl patch

ENV ALLTUBE="3.2.0"

RUN curl -L https://github.com/Rudloff/alltube/archive/${ALLTUBE}.tar.gz \
    | tar xzf -

COPY --from=composer /usr/local/bin/composer /usr/local/bin/composer

WORKDIR /alltube-${ALLTUBE}/

RUN composer install --no-interaction --optimize-autoloader --no-dev

RUN mv ./config/config.example.yml ./config/config.yml

COPY ./attach.css /tmp/
RUN cat /tmp/attach.css >> ./css/style.css

RUN mkdir -p ./templates_c && chmod -R 777 ./templates_c

RUN mv $(pwd) /alltube/

# -----------------------------------
# Build stage
# -----------------------------------
FROM ${ALPINE} AS build

RUN apk add --no-cache php83-fpm

# Fix PHP-FPM socket config
RUN sed -i 's?127.0.0.1:9000?/run/php-fpm.sock?' \
    /etc/php83/php-fpm.d/www.conf

WORKDIR /release

# Python symlink for compatibility
RUN mkdir -p usr/bin && ln -s /usr/bin/python3 usr/bin/python

COPY --from=alltube /alltube/ var/www/alltube/
COPY --from=yt-dlp /usr/bin/yt-dlp usr/bin/yt-dlp
COPY ./init.sh usr/bin/alltube
COPY ./nginx/ etc/nginx/

# -----------------------------------
# Final runtime image
# -----------------------------------
FROM ${ALPINE}

RUN apk add --no-cache \
    nginx ffmpeg python3 py3-pip \
    php83 php83-dom php83-fpm php83-gmp php83-xml php83-intl php83-json \
    php83-gettext php83-openssl php83-mbstring php83-simplexml \
    php83-tokenizer php83-xmlwriter

COPY --from=build /release/ /

EXPOSE 80

ENTRYPOINT ["alltube"]
