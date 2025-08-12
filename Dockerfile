# Base compatível com o composer.lock do projeto
FROM php:7.4-cli-alpine

# Dependências mínimas + extensões do PHP
RUN apk add --no-cache git unzip nodejs npm \
  && docker-php-ext-install pdo pdo_mysql zip bcmath

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . /app

# Instalar deps PHP respeitando o lock antigo
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-dev --prefer-dist --optimize-autoloader

# Build de assets (se falhar por versão de Node, não impede o deploy)
RUN npm install --legacy-peer-deps || npm install || true \
  && (npm run production || npm run build || npm run dev || true)

# Sobe app:
# - gera APP_KEY se não existir
# - cache de config
# - migra e seed
# - inicia servidor embutido do PHP na porta do Railway
CMD sh -c '\
  if [ -z "$APP_KEY" ]; then \
    php artisan key:generate --show | sed "s/^/base64:/" >/tmp/appkey && \
    export APP_KEY=$(cat /tmp/appkey); \
  fi && \
  php artisan config:cache && \
  php artisan migrate --force --seed && \
  php -S 0.0.0.0:${PORT:-8080} -t public'
