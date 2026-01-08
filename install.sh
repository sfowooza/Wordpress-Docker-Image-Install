#!/bin/bash

#############################################
# WordPress Docker Installer
# for Linux systems only
# by Avodah Systems (https://avodahsystems.com)
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Helper function for colored prompts
prompt() {
    local color=$1
    local text=$2
    echo -ne "${color}${text}${NC}"
}

# Database configurations
declare -A DB_IMAGES=(
    ["mysql"]="mysql:8.0"
    ["mariadb"]="mariadb:11.1"
    ["postgresql"]="postgres:16-alpine"
)

declare -A DB_HOSTS=(
    ["mysql"]="db:3306"
    ["mariadb"]="db:3306"
    ["postgresql"]="db:5432"
)

declare -A DB_ENV_PREFIXES=(
    ["mysql"]="MYSQL_"
    ["mariadb"]="MARIADB_"
    ["postgresql"]=""
)

declare -A DB_ROOT_ENVS=(
    ["mysql"]="MYSQL_ROOT_PASSWORD"
    ["mariadb"]="MARIADB_ROOT_PASSWORD"
    ["postgresql"]="POSTGRES_PASSWORD"
)

declare -A DB_DATA_PATHS=(
    ["mysql"]="/var/lib/mysql"
    ["mariadb"]="/var/lib/mysql"
    ["postgresql"]="/var/lib/postgresql/data"
)

declare -A DB_HEALTHCHECKS
DB_HEALTHCHECKS["mysql"]='["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p$DB_ROOT_PASSWORD"]'
DB_HEALTHCHECKS["mariadb"]='["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p$DB_ROOT_PASSWORD"]'
DB_HEALTHCHECKS["postgresql"]='["CMD-SHELL", "pg_isready -U $DB_USER -d $DB_NAME"]'

# Functions
print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   WordPress Docker Installer v1.1.0        ║"
    echo "║   by Avodah Systems                        ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -an 2>/dev/null | grep ":$port " | grep LISTEN >/dev/null; then
        return 1
    fi
    return 0
}

# Find the process using a port
find_port_process() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :$port | grep LISTEN
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn 2>/dev/null | grep ":$port "
    fi
}

# Validate email format
validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

# Validate password strength
validate_password() {
    local password=$1
    if [ ${#password} -lt 8 ]; then
        print_error "Password must be at least 8 characters long"
        return 1
    fi
    return 0
}

# Check if running as root or with sudo
check_permissions() {
    # Check if running on Linux
    if [ "$(uname)" != "Linux" ]; then
        print_error "This installer is designed for Linux systems only."
        echo ""
        echo "Detected OS: $(uname)"
        echo ""
        echo "For Windows: Use WSL2 or Docker Desktop with manual setup"
        echo "For macOS: Use Docker Desktop with manual setup"
        echo ""
        exit 1
    fi

    if [ ! -w . ]; then
        print_error "Cannot write to current directory. Please run with sudo:"
        echo ""
        echo "  sudo ./install.sh"
        echo ""
        echo "Or change directory ownership and run without sudo."
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    print_info "Checking dependencies..."

    local missing_deps=()

    if ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("docker")
    fi

    if ! command -v docker compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        missing_deps+=("docker-compose")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install the missing dependencies:"
        echo "  - Docker: https://docs.docker.com/get-docker/"
        echo "  - Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi

    print_success "All dependencies are installed"
}

# Display database selection menu
select_database() {
    echo ""
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════════╗"
    echo "║       Choose Your Database Backend         ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}Available database options:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) MySQL      ${BLUE}[Default]${NC} - Most popular, well-tested"
    echo -e "  ${GREEN}2${NC}) MariaDB    ${BLUE}[Drop-in MySQL replacement]${NC} - Enhanced features"
    echo -e "  ${GREEN}3${NC}) PostgreSQL ${BLUE}[Advanced]${NC} - Requires additional plugin"
    echo ""
    echo "  Info: MySQL and MariaDB work out of the box."
    echo "        PostgreSQL requires the 'WP PG4WP' plugin."
    echo ""

    while true; do
        prompt $GREEN "Select database [1-3, default: 1]: "
        read db_choice
        db_choice=${db_choice:-1}

        case $db_choice in
            1)
                db_type="mysql"
                db_display_name="MySQL"
                break
                ;;
            2)
                db_type="mariadb"
                db_display_name="MariaDB"
                break
                ;;
            3)
                db_type="postgresql"
                db_display_name="PostgreSQL"
                print_warning "PostgreSQL requires the WP PG4WP plugin."
                prompt $YELLOW "Continue with PostgreSQL? [Y/n]: "
                read continue_pg
                continue_pg=${continue_pg:-Y}
                if [[ $continue_pg =~ ^[Yy]$ ]]; then
                    break
                fi
                ;;
            *)
                print_error "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done

    print_success "Selected: $db_display_name"
}

# Main installation wizard
main_wizard() {
    print_header

    echo ""
    print_info "This wizard will guide you through installing WordPress with Docker."
    echo ""

    # Step 0: Database Selection
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Step 0: Database Selection${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    select_database

    # Step 1: Port selection
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Step 1: Port Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    while true; do
        prompt $GREEN "Enter the port for WordPress [default: 8080]: "
        read wp_port
        wp_port=${wp_port:-8080}

        # Validate port is a number
        if ! [[ $wp_port =~ ^[0-9]+$ ]]; then
            print_error "Port must be a number"
            continue
        fi

        # Validate port range
        if [ $wp_port -lt 1024 ] || [ $wp_port -gt 65535 ]; then
            print_error "Port must be between 1024 and 65535"
            continue
        fi

        # Check if port is available
        if ! check_port $wp_port; then
            print_error "Port $wp_port is already in use!"
            echo ""
            echo "Process using this port:"
            find_port_process $wp_port
            echo ""
            prompt $YELLOW "Choose a different port? [Y/n]: "
            read choose_different
            choose_different=${choose_different:-Y}
            if [[ $choose_different =~ ^[Yy]$ ]]; then
                continue
            else
                print_info "Exiting installation..."
                exit 0
            fi
        fi

        break
    done

    print_success "Port $wp_port is available"

    # Step 2: Site Title
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Step 2: Site Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    while true; do
        prompt $GREEN "Enter your site title [default: My WordPress Site]: "
        read site_title
        site_title=${site_title:-My WordPress Site}

        if [ -z "$site_title" ]; then
            print_error "Site title cannot be empty"
            continue
        fi

        break
    done

    print_success "Site title set to: $site_title"

    # Step 3: Admin Username
    echo ""
    while true; do
        prompt $GREEN "Enter admin username [default: admin]: "
        read admin_user
        admin_user=${admin_user:-admin}

        if [ -z "$admin_user" ]; then
            print_error "Username cannot be empty"
            continue
        fi

        # Validate username (alphanumeric and underscores only)
        if ! [[ $admin_user =~ ^[a-zA-Z0-9_]+$ ]]; then
            print_error "Username can only contain letters, numbers, and underscores"
            continue
        fi

        break
    done

    print_success "Admin username: $admin_user"

    # Step 4: Admin Password
    echo ""
    while true; do
        prompt $GREEN "Enter admin password (min 8 characters): "
        read -s admin_password
        echo ""

        if ! validate_password "$admin_password"; then
            continue
        fi

        # Confirm password
        prompt $GREEN "Confirm admin password: "
        read -s admin_password_confirm
        echo ""

        if [ "$admin_password" != "$admin_password_confirm" ]; then
            print_error "Passwords do not match"
            continue
        fi

        break
    done

    print_success "Admin password set"

    # Step 5: Admin Email
    echo ""
    while true; do
        prompt $GREEN "Enter admin email: "
        read admin_email

        if ! validate_email "$admin_email"; then
            print_error "Invalid email format"
            continue
        fi

        break
    done

    print_success "Admin email: $admin_email"

    # Step 6: WordPress URL
    echo ""
    prompt $GREEN "Enter WordPress URL [default: localhost:$wp_port]: "
    read wp_url_input
    wp_url_input=${wp_url_input:-localhost:$wp_port}
    # Remove http:// or https:// prefix if user provided it
    wp_url=$(echo "$wp_url_input" | sed -E 's|^(https?://)||g')
    print_success "WordPress URL: $wp_url"

    # Step 7: Database Configuration
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Step 3: Database Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    print_info "Database: $db_display_name"
    print_info "Press Enter to use auto-generated secure credentials"

    prompt $GREEN "Database name [default: wordpress]: "
    read db_name
    db_name=${db_name:-wordpress}

    prompt $GREEN "Database user [default: wpuser]: "
    read db_user
    db_user=${db_user:-wpuser}

    # Generate secure random password
    db_password=$(openssl rand -base64 16 | tr -d '/+=' | head -c 20)

    if [ "$db_type" = "postgresql" ]; then
        # PostgreSQL uses POSTGRES_PASSWORD instead of root password
        db_root_password=$db_password
    else
        db_root_password=$(openssl rand -base64 16 | tr -d '/+=' | head -c 20)
    fi

    print_success "Database configured with secure random passwords"

    # Set database-specific variables
    db_image=${DB_IMAGES[$db_type]}
    db_host=${DB_HOSTS[$db_type]}
    db_env_prefix=${DB_ENV_PREFIXES[$db_type]}
    db_root_env=${DB_ROOT_ENVS[$db_type]}
    db_data_path=${DB_DATA_PATHS[$db_type]}
    db_healthcheck=${DB_HEALTHCHECKS[$db_type]}

    # Set compose file based on database type
    case $db_type in
        mysql)
            compose_file="docker-compose.yml"
            ;;
        mariadb)
            compose_file="docker-compose.mariadb.yml"
            ;;
        postgresql)
            compose_file="docker-compose.postgresql.yml"
            ;;
        *)
            compose_file="docker-compose.yml"
            ;;
    esac

    # Save compose file name to .env for later use
    echo "COMPOSE_FILE=$compose_file" > .compose_file

    # Summary
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Installation Summary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Database:       $db_display_name"
    echo "  Port:           $wp_port"
    echo "  Site Title:     $site_title"
    echo "  Admin Username: $admin_user"
    echo "  Admin Email:    $admin_email"
    echo "  WordPress URL:  $wp_url"
    echo "  Database Name:  $db_name"
    echo "  Database User:  $db_user"
    echo ""

    # PostgreSQL notice
    if [ "$db_type" = "postgresql" ]; then
        echo -e "${YELLOW}Note: WP PG4WP plugin will be auto-installed for PostgreSQL support.${NC}"
        echo ""
    fi

    # Confirm installation
    prompt $YELLOW "Start installation with these settings? [Y/n]: "
    read confirm
    confirm=${confirm:-Y}

    if ! [[ $confirm =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    # Create .env file
    echo ""
    print_info "Creating environment configuration..."

    cat > .env << EOF
# WordPress Docker Configuration
# Generated by WordPress Docker Installer
# Date: $(date)

# Database Type: $db_display_name
DB_TYPE=$db_type
DB_IMAGE=$db_image
DB_HOST=$db_host
DB_ENV_PREFIX=$db_env_prefix
DB_ROOT_ENV=$db_root_env
DB_DATA_PATH=$db_data_path
DB_HEALTHCHECK_TEST=$db_healthcheck

# WordPress Configuration
WP_PORT=$wp_port
WP_SITE_TITLE=$site_title
WP_ADMIN_USER=$admin_user
WP_ADMIN_PASSWORD=$admin_password
WP_ADMIN_EMAIL=$admin_email
WP_URL=$wp_url

# Database Configuration
DB_NAME=$db_name
DB_USER=$db_user
DB_PASSWORD=$db_password
DB_ROOT_PASSWORD=$db_root_password

# Auto-install WordPress
WP_AUTO_INSTALL=true
EOF

    print_success "Environment file created"

    # Clean up any existing containers/volumes from previous installations
    print_info "Cleaning up any previous installation..."
    docker compose -f "$compose_file" down -v 2>/dev/null || true
    docker rm -f wp_installer_wordpress wp_installer_db 2>/dev/null || true

    # Start Docker containers
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Starting WordPress Installation${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    print_info "Pulling Docker images..."
    docker compose -f "$compose_file" pull

    print_info "Starting Docker containers..."
    docker compose -f "$compose_file" up -d

    echo ""
    print_info "Waiting for WordPress to be ready..."
    echo ""

    # Wait for WordPress to be healthy
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker compose -f "$compose_file" ps | grep wordpress | grep -q "healthy\|Up"; then
            break
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo ""

    # Wait for WordPress to be fully ready
    print_info "Waiting for WordPress to be ready..."
    sleep 15

    # Check if WordPress is accessible
    local max_http_attempts=30
    local http_attempt=0
    while [ $http_attempt -lt $max_http_attempts ]; do
        if docker compose -f "$compose_file" exec -T wordpress curl -f http://localhost/ >/dev/null 2>&1; then
            echo ""
            print_success "WordPress is responding!"
            break
        fi
        echo -n "."
        sleep 2
        http_attempt=$((http_attempt + 1))
    done
    echo ""

    # Install WordPress using WP-CLI
    print_info "Configuring WordPress..."

    # Wait a bit more to ensure database is fully ready
    sleep 5

    # Install WordPress core
    if docker compose -f "$compose_file" exec -T wordpress wp core install \
        --url="http://$wp_url" \
        --title="$site_title" \
        --admin_user="$admin_user" \
        --admin_password="$admin_password" \
        --admin_email="$admin_email" \
        --skip-email \
        --allow-root 2>/dev/null; then

        print_success "WordPress installed successfully!"

        # Explicitly set siteurl and home options (fix for WP-CLI issue)
        docker compose -f "$compose_file" exec -T wordpress wp option update siteurl "http://$wp_url" --allow-root >/dev/null 2>&1
        docker compose -f "$compose_file" exec -T wordpress wp option update home "http://$wp_url" --allow-root >/dev/null 2>&1

        # Set permalink structure
        docker compose -f "$compose_file" exec -T wordpress wp rewrite structure '/%postname%/' --allow-root >/dev/null 2>&1

        # Delete default content
        docker compose -f "$compose_file" exec -T wordpress wp post delete 1 --force --allow-root >/dev/null 2>&1 || true
        docker compose -f "$compose_file" exec -T wordpress wp post delete 2 --force --allow-root >/dev/null 2>&1 || true

        # Activate default theme
        docker compose -f "$compose_file" exec -T wordpress wp theme activate twentytwentyfour --allow-root >/dev/null 2>&1 || \
        docker compose -f "$compose_file" exec -T wordpress wp theme activate twentytwentythree --allow-root >/dev/null 2>&1 || true

        print_success "WordPress configured!"
    else
        print_warning "WP-CLI installation failed. WordPress may still be accessible via browser."
    fi

    # Install WP PG4WP plugin for PostgreSQL
    if [ "$db_type" = "postgresql" ]; then
        print_info "Installing WP PG4WP plugin for PostgreSQL support..."
        docker compose -f "$compose_file" exec -T wordpress wp plugin install wp-pg4wp --activate --allow-root 2>/dev/null || \
        print_warning "WP PG4WP plugin will need to be installed manually."
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Installation Complete!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Your WordPress site is ready!${NC}"
    echo ""
    echo "  Database:       $db_display_name"
    echo "  URL:            http://$wp_url"
    echo "  Admin Username: $admin_user"
    echo "  Admin Password: $admin_password"
    echo ""
    echo -e "${YELLOW}⚠ SAVE YOUR CREDENTIALS!${NC}"
    echo ""
    echo "Database credentials have been saved in the .env file."
    echo ""

    if [ "$db_type" = "postgresql" ]; then
        echo -e "${BLUE}PostgreSQL Notes:${NC}"
        echo "  - WP PG4WP plugin enables PostgreSQL compatibility"
        echo "  - Some plugins may not be fully compatible"
        echo ""
    fi

    echo "Useful commands:"
    echo "  Stop:    docker compose down"
    echo "  Start:   docker compose up -d"
    echo "  Logs:    docker compose logs -f"
    echo "  Shell:   docker compose exec wordpress bash"
    echo ""
    print_info "You can access your WordPress site at: http://$wp_url"
    echo ""

    # Save credentials to a file
    cat > credentials.txt << EOF
WordPress Docker Installer - Credentials
Generated: $(date)

Database Type: $db_display_name

WordPress Site:
---------------
URL: http://$wp_url
Admin Username: $admin_user
Admin Password: $admin_password
Admin Email: $admin_email

Database:
---------------
Database Type: $db_display_name
Database Name: $db_name
Database User: $db_user
Database Password: $db_password
EOF

    if [ "$db_type" != "postgresql" ]; then
        cat >> credentials.txt << EOF
Root Password: $db_root_password
EOF
    fi

    cat >> credentials.txt << EOF

Keep this file secure!
EOF

    print_success "Credentials saved to credentials.txt"
}

# Uninstall function
uninstall() {
    print_header
    print_warning "This will stop and remove all WordPress containers and volumes."
    echo ""
    prompt $YELLOW "Are you sure? [y/N]: "
    read confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        # Get compose file from .compose_file or default
        local compose_file="docker-compose.yml"
        if [ -f .compose_file ]; then
            compose_file=$(source .compose_file; echo $COMPOSE_FILE)
        fi

        print_info "Stopping containers..."
        docker compose -f "$compose_file" down -v

        print_info "Removing volumes..."
        docker volume rm wordpress-docker-installer_wordpress_data 2>/dev/null || true
        docker volume rm wordpress-docker-installer_db_data 2>/dev/null || true

        print_success "Uninstallation complete"
    else
        print_info "Uninstallation cancelled"
    fi
}

# Show help
show_help() {
    print_header
    echo ""
    echo "Usage: ./install.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  install    Run the installation wizard (default)"
    echo "  start      Start existing WordPress containers"
    echo "  stop       Stop WordPress containers"
    echo "  restart    Restart WordPress containers"
    echo "  logs       Show WordPress logs"
    echo "  status     Show container status"
    echo "  uninstall  Remove WordPress containers and volumes"
    echo "  help       Show this help message"
    echo ""
}

# Start containers
start_containers() {
    # Get compose file from .compose_file or default
    local compose_file="docker-compose.yml"
    if [ -f .compose_file ]; then
        compose_file=$(source .compose_file; echo $COMPOSE_FILE)
    fi

    print_info "Starting WordPress containers..."
    docker compose -f "$compose_file" up -d
    print_success "Containers started"
    echo ""
    echo "Access your site at: $(grep WP_URL .env 2>/dev/null | cut -d'=' -f2 || echo 'http://localhost:8080')"
}

# Stop containers
stop_containers() {
    # Get compose file from .compose_file or default
    local compose_file="docker-compose.yml"
    if [ -f .compose_file ]; then
        compose_file=$(source .compose_file; echo $COMPOSE_FILE)
    fi

    print_info "Stopping WordPress containers..."
    docker compose -f "$compose_file" down
    print_success "Containers stopped"
}

# Restart containers
restart_containers() {
    # Get compose file from .compose_file or default
    local compose_file="docker-compose.yml"
    if [ -f .compose_file ]; then
        compose_file=$(source .compose_file; echo $COMPOSE_FILE)
    fi

    print_info "Restarting WordPress containers..."
    docker compose -f "$compose_file" restart
    print_success "Containers restarted"
}

# Show logs
show_logs() {
    # Get compose file from .compose_file or default
    local compose_file="docker-compose.yml"
    if [ -f .compose_file ]; then
        compose_file=$(source .compose_file; echo $COMPOSE_FILE)
    fi

    docker compose -f "$compose_file" logs -f
}

# Show status
show_status() {
    # Get compose file from .compose_file or default
    local compose_file="docker-compose.yml"
    if [ -f .compose_file ]; then
        compose_file=$(source .compose_file; echo $COMPOSE_FILE)
    fi

    docker compose -f "$compose_file" ps
}

# Main script logic
case "${1:-install}" in
    install)
        check_permissions
        check_dependencies
        main_wizard
        ;;
    start)
        start_containers
        ;;
    stop)
        stop_containers
        ;;
    restart)
        restart_containers
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    uninstall)
        uninstall
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
