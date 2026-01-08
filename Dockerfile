FROM wordpress:6.7-php8.1

# Install PHP extensions for MySQL and WP-CLI
RUN set -ex && \
    docker-php-ext-install pdo pdo_mysql mysqli && \
    curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp && \
    wp --info
