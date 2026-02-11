{ALLTUBE}.tar.gz -O - | tar xzf -
COPY --from=composer /usr/bin/composer /usr/bin/composer
WORKDIR /alltube-${ALLTUBE}
RUN composer install --no-interaction --optimize-autoloader --no-dev
RUN cp ./config/config.example.yml ./config/config.yml
RUN touch ./css/style.css 
COPY ./attach.css* /tmp/
RUN [ -f /tmp/attach.css ] && cat /tmp/attach.css >> ./css/style.css || true
RUN chmod 777 ./templates_c/
RUN mv /alltube-${ALLTUBE} /alltube

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} AS build
RUN apk add --no-cache php83-fpm
WORKDIR /release/usr/bin/
# Ensure the symlink points to the Python 3.12+ provided by the base image
RUN ln -sf /usr/local/bin/python3 /release/usr/bin/python
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
      php83-tokenizer php83-xmlwriter php83-curl php83-ctype
      
COPY --from=build /release/ /
# Vital for yt-dlp to find the correct Python version
RUN ln -sf /usr/local/bin/python3 /usr/bin/python

EXPOSE 80
ENTRYPOINT ["alltube"]
