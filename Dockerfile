# ---------- Stage 1: build de assets (Node 14 p/ Laravel Mix antigo)
FROM node:14-alpine AS assets
WORKDIR /app
COPY package*.json ./
RUN npm ci --legacy-peer-deps || npm install
COPY . .
# tenta produção; se não houver script, tenta build/dev
RUN npm run production || npm run build || npm run dev

# ---------- Stage 2: runtime PHP 7.4 (compatível com composer.lock do projeto)
FROM php:7.4-cli-alpine

# deps para extensões e utilitários
RUN apk add --no-cache $PHPIZE_DEPS git unzip libzip-dev zlib-dev netcat-openbsd \
 && docker-php-ext-configure zip \
 && docker-php-ext-install pdo pdo_mysql zip bcmath

# composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . /app

# sobrescreve /public com o que foi gerado pelo Node
COPY --from=assets /app/public /app/public

ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-dev --prefer-dist --optimize-autoloader \
 && php artisan storage:link || true

# start: espera DB, cacheia config, migra (seed só se SEED=1) e serve com router do Laravel
CMD sh -c '\
  for i in $(seq 1 60); do nc -z ${DB_HOST} ${DB_PORT} && break || echo "Aguardando MySQL..."; sleep 2; done; \
  php artisan config:clear && php artisan cache:clear && php artisan view:clear && php artisan route:clear && \
  php artisan config:cache && \
  if [ "$SEED" = "1" ] && [ ! -f storage/seed.lock ]; then \
    php artisan migrate:fresh --force --seed && touch storage/seed.lock; \
  else \
    php artisan migrate --force; \
  fi && \
  php -S 0.0.0.0:${PORT:-8080} -t public server.php'
