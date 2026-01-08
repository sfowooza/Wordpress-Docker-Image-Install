FROM wordpress:latest

# Install required packages including PostgreSQL client
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI if not already present
RUN if ! command -v wp >/dev/null 2>&1; then \
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
        chmod +x wp-cli.phar && \
        mv wp-cli.phar /usr/local/bin/wp; \
    fi

# Use the default WordPress entrypoint
# WordPress will be installed automatically via environment variables
