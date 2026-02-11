ARG ALPINE="alpine:3.19"

# ---------------------------
# Composer stage
# ---------------------------
FROM ${ALPINE} AS composer
RUN apk add --no-cache php82 php82-json php82-phar php82-mbstring php82-openssl curl
RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/bin \
    --filename=composer

# ---------------------------
# yt-dlp stage (Standalone Binary)
# ---------------------------
FROM ${ALPINE} AS yt-dlp

ENV YTDLP_VERSION="2026.02.04"

RUN apk add --no-cache curl
RUN curl -L \
    https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp_linux \
    -o /usr/bin/yt-dlp \
    && chmod +x /usr/bin/yt-dlp

# ---------------------------
# AllTube stage (YOUR FORK)
# ---------------------------
FROM ${ALPINE} AS alltube

RUN apk add --no-cache \
    php82 php82-dom php82-gmp php82-xml php82-intl php82-json \
    php82-phar php82-gettext php82-openssl php82-mbstring \
    php82-simplexml php82-tokenizer php82-xmlwriter \
    curl tar git patch

# Pull YOUR fork instead of archived upstream
RUN git clone https://github.com/toyinswift/alltube.git /alltube

WORKDIR /alltube

COPY --from=composer /usr/bin/composer /usr/bin/composer
RUN composer install --no-interaction --optimize-autoloader --no-dev

RUN mv config/config.example.yml config/config.yml

# Optional: attach custom CSS if present
COPY ./attach.css /tmp/
RUN if [ -f /tmp/attach.css ]; then \
        cat /tmp/attach.css >> css/style.css ; \
    fi

RUN chmod 755 templates_c/

# ---------------------------
# Final runtime image
# ---------------------------
FROM ${ALPINE}

RUN apk add --no-cache \
    nginx ffmpeg \
    php82 php82-fpm php82-dom php82-gmp php82-xml php82-intl php82-json \
    php82-gettext php82-openssl php82-mbstring php82-simplexml \
    php82-tokenizer php82-xmlwriter

# Configure php-fpm socket
RUN sed -i 's?127.0.0.1:9000?/run/php-fpm.sock?' \
    /etc/php82/php-fpm.d/www.conf

COPY --from=alltube /alltube /var/www/alltube
COPY --from=yt-dlp /usr/bin/yt-dlp /usr/bin/yt-dlp
COPY ./init.sh /usr/bin/alltube
COPY ./nginx/ /etc/nginx/

RUN chmod +x /usr/bin/alltube

EXPOSE 80
ENTRYPOINT ["alltube"]

