ARG ALPINE="alpine:3.21"

FROM ${ALPINE} AS composer
# Updated to php83 packages for Alpine 3.21
RUN apk add --no-cache php83-json php83-phar php83-mbstring php83-openssl php83-iconv
RUN wget https://getcomposer.org -O - | php -- --install-dir=/usr/bin --filename=composer

FROM ${ALPINE} AS yt-dlp
# Latest February 2026 Release
ENV YTDLP="2026.02.04"
RUN wget https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP}/yt-dlp -O /usr/bin/yt-dlp
RUN chmod +x /usr/bin/yt-dlp

FROM ${ALPINE} AS alltube
RUN apk add --no-cache patch php83-dom php83-gmp php83-xml php83-intl php83-json php83-phar \
    php83-gettext php83-openssl php83-mbstring php83-simplexml php83-tokenizer php83-xmlwriter php83-curl
ENV ALLTUBE="3.2.0-alpha"
RUN wget https://github.com/Rudloff/alltube/archive/${ALLTUBE}.tar.gz -O - | tar xzf -
COPY --from=composer /usr/bin/composer /usr/bin/composer
WORKDIR /alltube-${ALLTUBE}
RUN composer install --no-interaction --optimize-autoloader --no-dev
RUN cp ./config/config.example.yml ./config/config.yml
COPY ./attach.css /tmp/
RUN cat /tmp/attach.css >> ./css/style.css
RUN chmod 777 ./templates_c/
RUN mv /alltube-${ALLTUBE} /alltube

FROM ${ALPINE} AS build
RUN apk add --no-cache php83-fpm
WORKDIR /release/usr/bin/
# Alpine 3.21 python3 is 3.12+, which satisfies yt-dlp requirements
RUN ln -sf /usr/bin/python3 /release/usr/bin/python
# Updated path for PHP 8.3
WORKDIR /release/etc/php83/php-fpm.d/
RUN sed 's?127.0.0.1:9000?/run/php-fpm.sock?' /etc/php83/php-fpm.d/www.conf > www.conf
COPY --from=alltube /alltube/ /release/var/www/alltube/
COPY --from=yt-dlp /usr/bin/yt-dlp /release/usr/bin/yt-dlp
COPY ./init.sh /release/usr/bin/alltube
COPY ./nginx/ /release/etc/nginx/

FROM ${ALPINE}
# Install latest dependencies
RUN apk add --no-cache nginx ffmpeg python3 \
    php83-dom php83-fpm php83-gmp php83-xml php83-intl php83-json php83-gettext \
    php83-openssl php83-mbstring php83-simplexml php83-tokenizer php83-xmlwriter php83-curl php83-ctype
    
COPY --from=build /release/ /
# Final link for the runtime environment
RUN ln -sf /usr/bin/python3 /usr/bin/python

EXPOSE 80
ENTRYPOINT ["alltube"]
