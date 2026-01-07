#!/bin/bash
set -e

# Get database type from environment
DB_TYPE=${DB_TYPE:-mysql}

echo "🔧 WordPress Auto-Install with $DB_TYPE database..."

# Wait for database to be ready
echo "⏳ Waiting for database..."

wait_for_db() {
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        case $DB_TYPE in
            mysql|mariadb)
                if mysqladmin ping -h"$WORDPRESS_DB_HOST" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" --silent 2>/dev/null; then
                    echo "✓ Database is ready!"
                    return 0
                fi
                ;;
            postgresql)
                # Extract host and port from WORDPRESS_DB_HOST (format: db:5432)
                DB_HOST=$(echo $WORDPRESS_DB_HOST | cut -d: -f1)
                DB_PORT=$(echo $WORDPRESS_DB_HOST | cut -d: -f2 -s)
                DB_PORT=${DB_PORT:-5432}

                if PGPASSWORD=$WORDPRESS_DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$WORDPRESS_DB_USER" -d "$WORDPRESS_DB_NAME" -c "SELECT 1" >/dev/null 2>&1; then
                    echo "✓ Database is ready!"
                    return 0
                fi
                ;;
        esac
        echo "  Waiting for database... ($((attempt + 1))/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    echo "⚠ Database connection timeout, continuing anyway..."
    return 0
}

wait_for_db

# Check if WordPress is already installed
if [ "$WP_AUTO_INSTALL" = "true" ] && [ ! -f /var/www/html/wp-config.php ]; then
    echo "📦 Installing WordPress..."

    # For PostgreSQL, we need to install the compatibility layer first
    if [ "$DB_TYPE" = "postgresql" ]; then
        echo "📥 Installing WP PG4WP plugin for PostgreSQL compatibility..."

        # Download and install WP PG4WP
        cd /var/www/html/wp-content/plugins
        if [ ! -d wp-pg4wp ]; then
            curl -sL https://github.com/kevinoid/wp-pg4wp/archive/refs/heads/master.tar.gz | tar -xz
            mv wp-pg4wp-master wp-pg4wp
        fi

        # Copy the db.php file to wp-content
        cp /var/www/html/wp-content/plugins/wp-pg4wp/db.php /var/www/html/wp-content/db.php

        echo "✓ WP PG4WP installed"
    fi

    # Use wp-cli to install WordPress
    wp core install \
        --url="$WORDPRESS_URL" \
        --title="$WORDPRESS_SITE_TITLE" \
        --admin_user="$WORDPRESS_ADMIN_USER" \
        --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
        --admin_email="$WORDPRESS_ADMIN_EMAIL" \
        --skip-email \
        --allow-root

    echo "✓ WordPress installed successfully!"

    # Set permalink structure
    wp rewrite structure '/%postname%/' --allow-root
    echo "✓ Permalink structure set"

    # Delete default post and page
    wp post delete 1 --force --allow-root 2>/dev/null || true
    wp post delete 2 --force --allow-root 2>/dev/null || true
    echo "✓ Default content removed"

    # Activate default theme
    wp theme activate twentytwentyfour --allow-root 2>/dev/null || wp theme activate twentytwentythree --allow-root 2>/dev/null || true
    echo "✓ Default theme activated"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ WordPress installation complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Database: $DB_TYPE"
    echo "  URL:      $WORDPRESS_URL"
    echo "  Username: $WORDPRESS_ADMIN_USER"
    echo "  Email:    $WORDPRESS_ADMIN_EMAIL"
    echo ""

elif [ -f /var/www/html/wp-config.php ]; then
    echo "✓ WordPress already installed, skipping..."
fi

# Execute Apache
echo "🚀 Starting Apache..."
exec apache2-foreground "$@"
