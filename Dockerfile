FROM php:7.4-cli-alpine

# Dependências de compilação do PHP + libzip e zlib
# (PHPIZE_DEPS = autoconf, make, g++, etc. necessários para compilar extensões)
RUN apk add --no-cache \
    $PHPIZE_DEPS \
    git unzip nodejs npm \
    libzip-dev zlib-dev

# Extensões PHP (zip precisa do libzip-dev/zlib-dev)
RUN docker-php-ext-configure zip \
 && docker-php-ext-install pdo pdo_mysql zip bcmath

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . /app

ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-dev --prefer-dist --optimize-autoloader

# Build de assets (mix/vite). Se der conflito de dependências, não quebra o deploy.
RUN npm install --legacy-peer-deps || npm install || true \
 && (npm run production || npm run build || npm run dev || true)

CMD sh -c '\
  if [ -z "$APP_KEY" ]; then \
    php artisan key:generate --show | sed "s/^/base64:/" >/tmp/appkey && \
    export APP_KEY=$(cat /tmp/appkey); \
  fi && \
  php artisan config:cache && \
  php artisan migrate --force --seed && \
  php -S 0.0.0.0:${PORT:-8080} -t public'
