ARG ALPINE_VERSION=3.20
ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} AS composer
# Clear apk cache immediately after install
RUN apk add --no-cache php83-json php83-phar php83-mbstring php83-openssl php83-iconv && \
    rm -rf /var/cache/apk/*
RUN wget https://getcomposer.org -O - | php -- --install-dir=/usr/bin --filename=composer

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} AS yt-dlp
ENV YTDLP="2026.02.04"
RUN wget https://github.com{YTDLP}/yt-dlp -O /usr/bin/yt-dlp && \
    chmod +x /usr/bin/yt-dlp
# Clear yt-dlp internal cache
RUN /usr/bin/yt-dlp --rm-cache-dir

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} AS alltube
RUN apk add --no-cache php83-json php83-phar php83-mbstring php83-openssl php83-dom \
    php83-gmp php83-xml php83-intl php83-gettext php83-simplexml php83-tokenizer php83-xmlwriter php83-curl && \
    rm -rf /var/cache/apk/*
ENV ALLTUBE="3.2.0-alpha"
RUN wget https://github.com{ALLTUBE}.tar.gz -O - | tar xzf -
COPY --from=composer /usr/bin/composer /usr/bin/composer
WORKDIR /alltube-${ALLTUBE}
# Clear composer cache after install to reduce image size
RUN composer install --no-interaction --optimize-autoloader --no-dev && \
    composer clear-cache
RUN cp ./config/config.example.yml ./config/config.yml
RUN touch ./css/style.css 
COPY ./attach.css* /tmp/
RUN [ -f /tmp/attach.css ] && cat /tmp/attach.css >> ./css/style.css || true
RUN chmod 777 ./templates_c/
RUN mv /alltube-${ALLTUBE} /alltube

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} AS build
RUN apk add --no-cache php83-fpm && rm -rf /var/cache/apk/*
# NUKE Python 3.9: Ensure /usr/bin/python points to the 3.12 binary
RUN rm -f /usr/bin/python3 /usr/bin/python && ln -sf /usr/local/bin/python3 /usr/bin/python
WORKDIR /release/etc/php83/php-fpm.d/
RUN sed 's?127.0.0.1:9000?/run/php-fpm.sock?' /etc/php83/php-fpm.d/www.conf > www.conf
COPY --from=alltube /alltube/ /release/var/www/alltube/
COPY --from=yt-dlp /usr/bin/yt-dlp /release/usr/bin/yt-dlp
COPY ./init.sh /release/usr/bin/alltube
RUN chmod +x /release/usr/bin/alltube
COPY ./nginx/ /release/etc/nginx/

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION}
RUN apk add --no-cache nginx ffmpeg php83-fpm php83-json php83-mbstring php83-openssl \
      php83-dom php83-gmp php83-xml php83-intl php83-gettext php83-simplexml \
      php83-tokenizer php83-xmlwriter php83-curl php83-ctype && \
    rm -rf /var/cache/apk/*
      
COPY --from=build /release/ /
# Final forced link to Python 3.12
RUN rm -f /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/local/bin/python3 /usr/bin/python3 && \
    ln -sf /usr/local/bin/python3 /usr/bin/python

EXPOSE 80
ENTRYPOINT ["alltube"]
