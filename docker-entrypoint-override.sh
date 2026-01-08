#!/bin/bash
# Auto-install script that runs in background after WordPress is ready
# This script is started by the original entrypoint

# Get database type from environment
DB_TYPE=${DB_TYPE:-mysql}

echo "🔧 WordPress Auto-Install with $DB_TYPE database..."

# Wait for WordPress to be fully installed by original entrypoint
echo "⏳ Waiting for WordPress to be ready..."
local max_attempts=60
local attempt=0

while [ $attempt -lt $max_attempts ]; do
    if [ -f /var/www/html/wp-config.php ] && [ -f /var/www/html/wp-settings.php ]; then
        echo "✓ WordPress files ready!"
        break
    fi
    echo "  Waiting for WordPress... ($((attempt + 1))/$max_attempts)"
    sleep 2
    attempt=$((attempt + 1))
done

# Wait for database
echo "⏳ Waiting for database connection..."
attempt=0

while [ $attempt -lt 30 ]; do
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
    echo "  Waiting for database... ($((attempt + 1))/30"
    sleep 2
    attempt=$((attempt + 1))
done

# Check if already installed
if [ -f /var/www/html/.wp-installed ]; then
    echo "✓ WordPress already configured"
    exit 0
fi

# Check if WordPress is already installed (wp-config.php exists and is not empty)
if wp core is-installed --allow-root 2>/dev/null; then
    echo "✓ WordPress already installed"
    touch /var/www/html/.wp-installed
    exit 0
fi

# Install WordPress
echo "🚀 Installing WordPress..."

# Wait a bit more for everything to be ready
sleep 5

if wp core install \
    --url="$WORDPRESS_URL" \
    --title="$WORDPRESS_SITE_TITLE" \
    --admin_user="$WORDPRESS_ADMIN_USER" \
    --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
    --admin_email="$WORDPRESS_ADMIN_EMAIL" \
    --skip-email \
    --allow-root; then

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
    echo "⚠ WordPress installation may have failed, trying again..."
fi
