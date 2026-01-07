# WordPress Docker Installer

A simple, one-command WordPress installer using Docker. Choose from MySQL, MariaDB, or PostgreSQL databases. Just pull the image, run the installer script, and have WordPress running in minutes.

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-%23117ac6?style=for-the-badge&logo=WordPress&logoColor=white)

By [Avodah Systems](https://avodahsystems.com)

## Features

- **Interactive Installation Wizard** - Guided setup with prompts
- **Multiple Database Support** - Choose from MySQL, MariaDB, or PostgreSQL
- **Port Availability Check** - Automatically detects if a port is in use
- **Auto-Configuration** - No manual database setup required
- **Secure Defaults** - Randomly generated database passwords
- **One-Command Management** - Start, stop, and manage with simple commands
- **Latest WordPress** - Always runs the latest WordPress version

## Supported Databases

| Database | Version | Description |
|----------|---------|-------------|
| **MySQL** | 8.0 | Most popular, well-tested (Default) |
| **MariaDB** | 11.1 | Enhanced MySQL drop-in replacement |
| **PostgreSQL** | 16-alpine | Advanced features with WP PG4WP plugin |

> **Note:** PostgreSQL uses the WP PG4WP compatibility layer for full WordPress support.

## Quick Start

### Prerequisites

- Docker installed on your system
- Docker Compose installed

### Installation

1. Clone or download this repository:

```bash
git clone https://github.com/sfowooza/Wordpress-Docker-Image-Install.git
cd Wordpress-Docker-Image-Install
```

2. Make the installer executable:

```bash
chmod +x install.sh
```

3. Run the installation wizard (may require sudo):

```bash
sudo ./install.sh
```

### Installation Wizard

The wizard will prompt you for:

1. **Database Selection** - Choose MySQL, MariaDB, or PostgreSQL
2. **Port** - The port to run WordPress on (default: 8080)
   - Automatically checks if port is available
   - Notifies you if port is in use and what process is using it
3. **Site Title** - Your WordPress site name
4. **Admin Username** - Your WordPress admin username
5. **Admin Password** - Your WordPress admin password (min 8 characters)
6. **Admin Email** - Your WordPress admin email
7. **WordPress URL** - Your site URL (default: localhost:PORT)
8. **Database** - Press Enter to use auto-generated secure credentials

## Usage

### Start WordPress

```bash
./install.sh start
```

### Stop WordPress

```bash
./install.sh stop
```

### Restart WordPress

```bash
./install.sh restart
```

### View Logs

```bash
./install.sh logs
```

### Check Status

```bash
./install.sh status
```

### Uninstall

```bash
./install.sh uninstall
```

## Database-Specific Notes

### MySQL (Default)
- Most widely used database for WordPress
- Full plugin compatibility
- Best overall support

### MariaDB
- Drop-in MySQL replacement
- Performance improvements
- Fully compatible with WordPress

### PostgreSQL
- Requires WP PG4WP compatibility layer (auto-installed)
- Some plugins may have limited compatibility
- Better for complex data structures

## Accessing WordPress

After installation, access your WordPress site at:

- **Site**: `http://localhost:YOUR_PORT`
- **Admin**: `http://localhost:YOUR_PORT/wp-admin`

## Credentials

Your login credentials are saved in:
- `.env` - Environment configuration
- `credentials.txt` - Human-readable credentials file

**Keep these files secure!**

## Directory Structure

```
wordpress-docker-installer/
├── install.sh              # Main installer script
├── docker-compose.yml      # Docker orchestration
├── Dockerfile              # WordPress image with custom entrypoint
├── docker-entrypoint.sh    # Auto-install script with multi-DB support
├── .env                    # Generated environment file
├── credentials.txt         # Generated credentials file
└── README.md               # This file
```

## Troubleshooting

### Port Already in Use

The installer will automatically detect if a port is in use and show you the process occupying it. Choose a different port.

### WordPress Not Loading

Check container status:
```bash
./install.sh status
```

View logs:
```bash
./install.sh logs
```

### PostgreSQL Issues

If you experience issues with PostgreSQL:
1. Verify WP PG4WP plugin is active
2. Check database connection in logs
3. Some plugins may not be fully compatible

### Reset Everything

```bash
./install.sh uninstall
./install.sh
```

## Docker Images Used

- `wordpress:latest` - Latest WordPress with Apache
- `mysql:8.0` - MySQL 8.0 database
- `mariadb:11.1` - MariaDB 11.1 database
- `postgres:16-alpine` - PostgreSQL 16 database

## Security Notes

1. Database passwords are auto-generated and stored in `.env`
2. Change your admin password after first login
3. Don't commit `.env` or `credentials.txt` to version control
4. Use HTTPS in production (requires reverse proxy)

## Development

### Build Custom Image

```bash
docker build -t my-wordpress .
```

### Run with Custom Configuration

```bash
cp .env.example .env
# Edit .env with your settings
docker compose up -d
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_TYPE` | Database type (mysql/mariadb/postgresql) | mysql |
| `DB_IMAGE` | Database Docker image | mysql:8.0 |
| `WP_PORT` | WordPress port | 8080 |
| `WP_ADMIN_USER` | WordPress admin username | admin |
| `WP_ADMIN_EMAIL` | WordPress admin email | admin@example.com |
| `DB_NAME` | Database name | wordpress |
| `DB_USER` | Database user | wpuser |

## License

GPL v2 or later

## Author

**Avodah Systems**
Website: https://avodahsystems.com

## Support

For issues and questions, please visit:
- GitHub Issues: https://github.com/sfowooza/Wordpress-Docker-Image-Install/issues
- WordPress.org: https://wordpress.org/support/
