#!/bin/bash
set -e

# Get database type from environment
DB_TYPE=${DB_TYPE:-mysql}

echo "🔧 WordPress Auto-Install with $DB_TYPE database..."

# First, run the original docker-entrypoint to download WordPress if needed
# The original entrypoint is at /usr/local/bin/docker-entrypoint.sh
if [ ! -f /var/www/html/wp-settings.php ]; then
    echo "📥 Downloading WordPress files..."
fi

# Call the original entrypoint with --ignore-root-owner to set up WordPress
# This will download WordPress and create wp-config.php
/usr/local/bin/docker-entrypoint.sh.orig --ignore-root-owner

# Now check if we should auto-configure WordPress
if [ "$WP_AUTO_INSTALL" = "true" ] && [ ! -f /var/www/html/.wp-installed ]; then
    echo "📦 Configuring WordPress..."

    # Wait for database to be ready
    echo "⏳ Waiting for database connection..."

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        case $DB_TYPE in
            mysql|mariadb)
                if mysqladmin ping -h"$WORDPRESS_DB_HOST" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" --silent 2>/dev/null; then
                    echo "✓ Database is ready!"
                    break
                fi
                ;;
            postgresql)
                DB_HOST=$(echo $WORDPRESS_DB_HOST | cut -d: -f1)
                DB_PORT=$(echo $WORDPRESS_DB_HOST | cut -d: -f2 -s)
                DB_PORT=${DB_PORT:-5432}

                if PGPASSWORD=$WORDPRESS_DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$WORDPRESS_DB_USER" -d "$WORDPRESS_DB_NAME" -c "SELECT 1" >/dev/null 2>&1; then
                    echo "✓ Database is ready!"
                    break
                fi
                ;;
        esac
        echo "  Waiting... ($((attempt + 1))/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    # Use wp-cli to install WordPress
    echo "🚀 Installing WordPress..."
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

    # Delete default content
    wp post delete 1 --force --allow-root 2>/dev/null || true
    wp post delete 2 --force --allow-root 2>/dev/null || true
    echo "✓ Default content removed"

    # Activate default theme
    wp theme activate twentytwentyfour --allow-root 2>/dev/null || \
    wp theme activate twentytwentythree --allow-root 2>/dev/null || true
    echo "✓ Default theme activated"

    # Mark as installed
    touch /var/www/html/.wp-installed

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ WordPress setup complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  URL:      $WORDPRESS_URL"
    echo "  Username: $WORDPRESS_ADMIN_USER"
    echo ""
else
    echo "✓ WordPress already configured"
fi

echo "🚀 Starting Apache..."
exec apache2-foreground "$@"
