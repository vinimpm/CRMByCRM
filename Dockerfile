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

RUN apk add --no-cache netcat-openbsd

CMD sh -c '\
  # espera DB
  for i in $(seq 1 60); do nc -z ${DB_HOST} ${DB_PORT} && break || echo "Aguardando MySQL..."; sleep 2; done; \
  php artisan config:clear && php artisan cache:clear && php artisan view:clear && php artisan route:clear && \
  php artisan config:cache && \
  if [ "$SEED" = "1" ] && [ ! -f storage/seed.lock ]; then \
      echo "Seed inicial..."; \
      php artisan migrate:fresh --force --seed && \
      touch storage/seed.lock; \
  else \
      php artisan migrate --force; \
  fi && \
  php -S 0.0.0.0:${PORT:-8080} -t public server.php'