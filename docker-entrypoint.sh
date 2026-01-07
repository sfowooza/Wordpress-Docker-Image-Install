#!/bin/bash
set -e

# If WP_AUTO_INSTALL is set, we'll handle WordPress installation automatically
if [ "$WP_AUTO_INSTALL" = "true" ]; then
    echo "🔧 WordPress Auto-Install enabled..."

    # Wait for database to be ready
    echo "⏳ Waiting for database..."
    max_attempts=30
    attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if mysqladmin ping -h"$WORDPRESS_DB_HOST" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" --silent 2>/dev/null; then
            echo "✓ Database is ready!"
            break
        fi
        echo "  Waiting for database... ($((attempt + 1))/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    # Check if WordPress is already installed
    if [ ! -f /var/www/html/wp-config.php ]; then
        echo "📦 Installing WordPress..."

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

        # Install and activate a default theme (Twenty Twenty-Four)
        wp theme activate twentytwentyfour --allow-root 2>/dev/null || true
        echo "✓ Default theme activated"

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✓ WordPress installation complete!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  URL:      $WORDPRESS_URL"
        echo "  Username: $WORDPRESS_ADMIN_USER"
        echo "  Email:    $WORDPRESS_ADMIN_EMAIL"
        echo ""
    else
        echo "✓ WordPress already installed, skipping..."
    fi
fi

# Execute the original docker-entrypoint.sh
# First, let's check if we need to source the original entrypoint
if [ -f /usr/local/bin/docker-entrypoint-original.sh ]; then
    # Original entrypoint was backed up
    . /usr/local/bin/docker-entrypoint-original.sh
else
    # Try to find and execute the original WordPress entrypoint
    if command -v docker-entrypoint.sh >/dev/null 2>&1; then
        # The original entrypoint is in PATH
        /original-entrypoint.sh "$@" 2>/dev/null || \
        docker-entrypoint.sh.orig "$@" 2>/dev/null || \
        exec apache2-foreground
    else
        # Fallback to apache2-foreground directly
        exec apache2-foreground "$@"
    fi
fi
