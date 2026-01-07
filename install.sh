#!/bin/bash

#############################################
# WordPress Docker Installer
# by Avodah Systems (https://avodahsystems.com)
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   WordPress Docker Installer v1.0.0        ║"
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

# Main installation wizard
main_wizard() {
    print_header

    echo ""
    print_info "This wizard will guide you through installing WordPress with Docker."
    echo ""

    # Step 1: Port selection
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Step 1: Port Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    while true; do
        read -p "$(echo -e ${GREEN}Enter the port for WordPress [default: 8080]: ${NC})" wp_port
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
            read -p "$(echo -e ${YELLOW}Choose a different port? [Y/n]: ${NC})" choose_different
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
        read -p "$(echo -e ${GREEN}Enter your site title [default: My WordPress Site]: ${NC})" site_title
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
        read -p "$(echo -e ${GREEN}Enter admin username [default: admin]: ${NC})" admin_user
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
        read -s -p "$(echo -e ${GREEN}Enter admin password (min 8 characters): ${NC})" admin_password
        echo ""

        if ! validate_password "$admin_password"; then
            continue
        fi

        # Confirm password
        read -s -p "$(echo -e ${GREEN}Confirm admin password: ${NC})" admin_password_confirm
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
        read -p "$(echo -e ${GREEN}Enter admin email: ${NC})" admin_email

        if ! validate_email "$admin_email"; then
            print_error "Invalid email format"
            continue
        fi

        break
    done

    print_success "Admin email: $admin_email"

    # Step 6: WordPress URL
    echo ""
    read -p "$(echo -e ${GREEN}Enter WordPress URL [default: localhost:$wp_port]: ${NC})" wp_url
    wp_url=${wp_url:-localhost:$wp_port}
    print_success "WordPress URL: $wp_url"

    # Step 7: Database Configuration (optional)
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Step 3: Database Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    print_info "Press Enter to use auto-generated secure credentials"

    read -p "$(echo -e ${GREEN}Database name [default: wordpress]: ${NC})" db_name
    db_name=${db_name:-wordpress}

    read -p "$(echo -e ${GREEN}Database user [default: wpuser]: ${NC})" db_user
    db_user=${db_user:-wpuser}

    # Generate secure random password if not provided
    db_password=$(openssl rand -base64 16 | tr -d '/+=' | head -c 20)
    db_root_password=$(openssl rand -base64 16 | tr -d '/+=' | head -c 20)

    print_success "Database configured with secure random passwords"

    # Summary
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Installation Summary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Port:           $wp_port"
    echo "  Site Title:     $site_title"
    echo "  Admin Username: $admin_user"
    echo "  Admin Email:    $admin_email"
    echo "  WordPress URL:  $wp_url"
    echo "  Database Name:  $db_name"
    echo "  Database User:  $db_user"
    echo ""

    # Confirm installation
    read -p "$(echo -e ${YELLOW}Start installation with these settings? [Y/n]: ${NC})" confirm
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

    # Start Docker containers
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Starting WordPress Installation${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    print_info "Pulling Docker images..."
    docker compose pull

    print_info "Starting Docker containers..."
    docker compose up -d

    echo ""
    print_info "Waiting for WordPress to be ready..."
    echo ""

    # Wait for WordPress to be healthy
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker compose ps | grep wordpress | grep -q "healthy\|Up"; then
            break
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo ""

    # Wait additional time for WP-CLI to be available
    print_info "Finalizing installation..."
    sleep 10

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Installation Complete!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Your WordPress site is ready!${NC}"
    echo ""
    echo "  URL:            http://$wp_url"
    echo "  Admin Username: $admin_user"
    echo "  Admin Password: $admin_password"
    echo ""
    echo -e "${YELLOW}⚠ SAVE YOUR CREDENTIALS!${NC}"
    echo ""
    echo "Database credentials have been saved in the .env file."
    echo ""
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

WordPress Site:
---------------
URL: http://$wp_url
Admin Username: $admin_user
Admin Password: $admin_password
Admin Email: $admin_email

Database:
---------------
Database Name: $db_name
Database User: $db_user
Database Password: $db_password
Root Password: $db_root_password

Keep this file secure!
EOF

    print_success "Credentials saved to credentials.txt"
}

# Uninstall function
uninstall() {
    print_header
    print_warning "This will stop and remove all WordPress containers and volumes."
    echo ""
    read -p "$(echo -e ${YELLOW}Are you sure? [y/N]: ${NC})" confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_info "Stopping containers..."
        docker compose down -v

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
    print_info "Starting WordPress containers..."
    docker compose up -d
    print_success "Containers started"
    echo ""
    echo "Access your site at: $(grep WP_URL .env 2>/dev/null | cut -d'=' -f2 || echo 'http://localhost:8080')"
}

# Stop containers
stop_containers() {
    print_info "Stopping WordPress containers..."
    docker compose down
    print_success "Containers stopped"
}

# Restart containers
restart_containers() {
    print_info "Restarting WordPress containers..."
    docker compose restart
    print_success "Containers restarted"
}

# Show logs
show_logs() {
    docker compose logs -f
}

# Show status
show_status() {
    docker compose ps
}

# Main script logic
case "${1:-install}" in
    install)
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
