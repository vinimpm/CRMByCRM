# ===== Runtime PHP + Composer + Node (alpine, leve) =====
FROM php:8.2-cli-alpine

# libs básicas e extensões necessárias
RUN apk add --no-cache git unzip nodejs npm \
  && docker-php-ext-install pdo pdo_mysql

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . /app

# Instalar deps PHP (sem dev) e otimizar autoloader
RUN composer install --no-dev --prefer-dist --optimize-autoloader

# Build dos assets (se falhar, não quebra o deploy)
RUN npm install && npm run build || true

# Pequeno entrypoint: gera APP_KEY se não existir e aplica migrações
CMD sh -c '\
  if [ -z "$APP_KEY" ]; then \
    php artisan key:generate --show | sed "s/^/base64:/" >/tmp/appkey && \
    export APP_KEY=$(cat /tmp/appkey); \
  fi && \
  php artisan config:cache && \
  php artisan migrate --force --seed && \
  php -S 0.0.0.0:${PORT:-8080} -t public'
