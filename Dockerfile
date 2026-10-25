# PHP runtime: pinned to a serversideup/php release that ships a PHP build
# patched for PHP2Shell (CVE-2026-109618 / CVE-2026-109619).
# 8.2-fpm-nginx-v5.0.3 = PHP 8.2.35, Debian 13 (trixie),
# digest sha256:5f4e78ea633681f33ece37a61ac0aba92f6d4d4bef5a37f2a76cc12824e3bbd9
ARG PHP_VERSION=8.2
ARG PHP_IMAGE_VERSION=v5.0.3
ARG NODE_VERSION
ARG DB_CONNECTION
ARG DB_DATABASE

# Base Image
FROM ghcr.io/serversideup/php:${PHP_VERSION}-fpm-nginx-${PHP_IMAGE_VERSION} AS base
# Mitigation (not the fix): keep session.upload_progress off, as recommended by the PHP team.
ENV PHP_SESSION_UPLOAD_PROGRESS_ENABLED=0
ENV AUTORUN_ENABLED=1
ENV AUTORUN_LARAVEL_MIGRATION=0
ENV PHP_OPCACHE_ENABLE=1

# Copy files
WORKDIR /var/www/html
COPY --chown=www-data:www-data . /var/www/html

# Install Composer dependencies
RUN composer install --optimize-autoloader && composer ts

# Build Frontend Assets
FROM node:${NODE_VERSION}-alpine AS node
WORKDIR /app
COPY --from=base /var/www/html .
RUN npm ci --no-audit && npm run quick-build

# Copy the built assets to base image
FROM base
COPY --chown=www-data:www-data --from=node /app/public /var/www/html/public
RUN chmod -R 755 /var/www/html/public

# Create the SQLite directory and set the owner to www-data
USER root
ARG DB_CONNECTION
ARG DB_DATABASE
ENV DB_CONNECTION=$DB_CONNECTION
ENV DB_DATABASE=$DB_DATABASE
RUN mkdir -p /data \
    && touch "$DB_DATABASE" \
    && chown -R www-data:www-data "$DB_DATABASE" \
    && chmod -R 777 "$DB_DATABASE" \
    && php artisan migrate --force --seed

# Switch back to unprivileged user
USER www-data

LABEL org.opencontainers.image.source=https://github.com/adwinying/hotel-hamlet
