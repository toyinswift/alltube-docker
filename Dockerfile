ARG ALPINE="python:3.20-alpine"

FROM ${ALPINE} AS composer
RUN apk add --no-cache php81-json php81-phar php81-mbstring php81-openssl
RUN wget https://install.phpcomposer.com/installer -O - | php

FROM ${ALPINE} AS yt-dlp
ENV YTDLP="2026.02.04"
RUN wget https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP}/yt-dlp -O /usr/bin/yt-dlp
RUN chmod +x /usr/bin/yt-dlp

FROM ${ALPINE} AS alltube
RUN apk add --no-cache php81-json php81-phar php81-mbstring php81-openssl
RUN apk add --no-cache patch php81-dom php81-gmp php81-xml php81-intl php81-gettext php81-simplexml php81-tokenizer php81-xmlwriter
ENV ALLTUBE="3.2.0-alpha"
RUN wget https://github.com/Rudloff/alltube/archive/${ALLTUBE}.tar.gz -O - | tar xzf -
COPY --from=composer /composer.phar /usr/bin/composer
WORKDIR ./alltube-${ALLTUBE}/
RUN composer install --no-interaction --optimize-autoloader --no-dev
RUN mv ./config/config.example.yml ./config/config.yml
COPY ./attach.css /tmp/
RUN cat /tmp/attach.css >> ./css/style.css
RUN chmod 777 ./templates_c/
RUN mv $(pwd) /alltube/

FROM ${ALPINE} AS build
RUN apk add --no-cache php81-fpm
WORKDIR /release/usr/bin/
RUN ln -sf /usr/bin/python3 /release/usr/bin/python
WORKDIR /release/etc/php81/php-fpm.d/
RUN sed 's?127.0.0.1:9000?/run/php-fpm.sock?' /etc/php81/php-fpm.d/www.conf > www.conf
COPY --from=alltube /alltube/ /release/var/www/alltube/
COPY --from=yt-dlp /usr/bin/yt-dlp /release/usr/bin/yt-dlp
COPY ./init.sh /release/usr/bin/alltube
COPY ./nginx/ /release/etc/nginx/

FROM ${ALPINE}
RUN apk add --no-cache nginx ffmpeg php81-fpm php81-json php81-mbstring php81-openssl \
      php81-dom php81-gmp php81-xml php81-intl php81-gettext php81-simplexml php81-tokenizer php81-xmlwriter
COPY --from=build /release/ /
EXPOSE 80
ENTRYPOINT ["alltube"]
