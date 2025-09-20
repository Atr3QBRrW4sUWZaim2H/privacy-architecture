#!/bin/bash

# Privacy Architecture Setup Script
# This script helps set up the privacy architecture project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create directory if it doesn't exist
create_directory() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        print_success "Created directory: $1"
    else
        print_status "Directory already exists: $1"
    fi
}

# Function to create file if it doesn't exist
create_file() {
    if [ ! -f "$1" ]; then
        touch "$1"
        print_success "Created file: $1"
    else
        print_status "File already exists: $1"
    fi
}

# Main setup function
main() {
    print_status "Starting Privacy Architecture Setup..."
    
    # Create project structure
    print_status "Creating project directory structure..."
    create_directory "docs"
    create_directory "scripts"
    create_directory "config/production"
    create_directory "config/development"
    create_directory "config/templates"
    create_directory "data"
    create_directory "logs"
    create_directory "backups"
    create_directory "archive"
    
    # Create configuration files
    print_status "Creating configuration files..."
    create_file "config/production/.env"
    create_file "config/development/.env"
    create_file "config/templates/.env.example"
    
    # Create data files
    print_status "Creating data files..."
    create_file "data/services.json"
    create_file "data/migration-log.json"
    create_file "data/cost-tracking.json"
    
    # Create log files
    print_status "Creating log files..."
    create_file "logs/setup.log"
    create_file "logs/migration.log"
    create_file "logs/audit.log"
    create_file "logs/errors.log"
    
    # Create backup files
    print_status "Creating backup files..."
    create_file "backups/1password-vault-backup.json"
    create_file "backups/fastmail-aliases.json"
    create_file "backups/privacy-cards.json"
    
    # Set up environment template
    print_status "Setting up environment template..."
    cat > config/templates/.env.example << EOF
# Privacy Architecture Environment Configuration

# Email Configuration
FASTMAIL_EMAIL=your-email@fastmail.com
FASTMAIL_PASSWORD=your-fastmail-password
DOMAIN=softmoth.com

# Phone Configuration
HUSHED_NUMBER=+1234567890
HUSHED_PASSWORD=your-hushed-password

# Payment Configuration
PRIVACY_API_KEY=your-privacy-api-key
PRIVACY_ACCOUNT_ID=your-privacy-account-id

# 1Password Configuration
ONEPASSWORD_VAULT=your-vault-name
ONEPASSWORD_ACCOUNT=your-account-name

# Security Configuration
ENCRYPTION_KEY=your-encryption-key
BACKUP_PASSPHRASE=your-backup-passphrase

# Monitoring Configuration
LOG_LEVEL=INFO
AUDIT_ENABLED=true
BACKUP_ENABLED=true
EOF

    # Create service configuration
    print_status "Creating service configuration..."
    cat > config/templates/services.json << EOF
{
  "services": {
    "email": {
      "provider": "fastmail",
      "domain": "softmoth.com",
      "aliases": []
    },
    "phone": {
      "provider": "hushed",
      "numbers": []
    },
    "payment": {
      "provider": "privacy",
      "cards": []
    },
    "2fa": {
      "provider": "1password",
      "tokens": []
    }
  },
  "migration": {
    "completed": [],
    "pending": [],
    "failed": []
  },
  "costs": {
    "monthly": 11.25,
    "annual": 135,
    "breakdown": {
      "fastmail": 5.00,
      "hushed": 5.00,
      "domain": 1.25,
      "privacy": 0.00
    }
  }
}
EOF

    # Create migration log template
    print_status "Creating migration log template..."
    cat > config/templates/migration-log.json << EOF
{
  "migrations": [
    {
      "date": "2024-09-19",
      "service": "monarch",
      "email": "monarch@softmoth.com",
      "2fa": "totp",
      "payment": "privacy-card-001",
      "status": "completed",
      "notes": "Successfully migrated Monarch Budget service"
    }
  ],
  "statistics": {
    "total_migrated": 0,
    "successful": 0,
    "failed": 0,
    "pending": 0
  }
}
EOF

    # Create cost tracking template
    print_status "Creating cost tracking template..."
    cat > config/templates/cost-tracking.json << EOF
{
  "monthly_costs": {
    "fastmail": 5.00,
    "hushed": 5.00,
    "domain": 1.25,
    "privacy": 0.00,
    "total": 11.25
  },
  "annual_costs": {
    "domain_renewal": 15.00,
    "total_annual": 135.00
  },
  "tracking": {
    "start_date": "2024-09-19",
    "last_updated": "2024-09-19",
    "currency": "USD"
  }
}
EOF

    # Set up log rotation
    print_status "Setting up log rotation..."
    cat > config/templates/logrotate.conf << EOF
# Log rotation configuration for Privacy Architecture
/mnt/dev/projects/privacy-architecture/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    # Create backup script
    print_status "Creating backup script..."
    cat > scripts/backup.sh << 'EOF'
#!/bin/bash

# Privacy Architecture Backup Script
# This script backs up all important data

set -e

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Starting backup to $BACKUP_DIR..."

# Backup 1Password vault (if accessible)
if command -v op >/dev/null 2>&1; then
    echo "Backing up 1Password vault..."
    op export --format=json > "$BACKUP_DIR/1password-vault.json" || echo "1Password backup failed"
fi

# Backup configuration files
echo "Backing up configuration files..."
cp -r config/ "$BACKUP_DIR/"

# Backup data files
echo "Backing up data files..."
cp -r data/ "$BACKUP_DIR/"

# Backup logs
echo "Backing up logs..."
cp -r logs/ "$BACKUP_DIR/"

# Create archive
echo "Creating backup archive..."
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup completed: $BACKUP_DIR.tar.gz"
EOF

    chmod +x scripts/backup.sh

    # Create audit script
    print_status "Creating audit script..."
    cat > scripts/audit.sh << 'EOF'
#!/bin/bash

# Privacy Architecture Audit Script
# This script audits the privacy architecture for issues

set -e

echo "Starting Privacy Architecture Audit..."

# Check if required tools are installed
echo "Checking required tools..."
command -v op >/dev/null 2>&1 || echo "WARNING: 1Password CLI not found"
command -v curl >/dev/null 2>&1 || echo "WARNING: curl not found"
command -v jq >/dev/null 2>&1 || echo "WARNING: jq not found"

# Check configuration files
echo "Checking configuration files..."
if [ ! -f "config/production/.env" ]; then
    echo "WARNING: Production environment file not found"
fi

if [ ! -f "data/services.json" ]; then
    echo "WARNING: Services data file not found"
fi

# Check log files
echo "Checking log files..."
if [ ! -d "logs" ]; then
    echo "WARNING: Logs directory not found"
fi

# Check backup files
echo "Checking backup files..."
if [ ! -d "backups" ]; then
    echo "WARNING: Backups directory not found"
fi

echo "Audit completed. Check warnings above."
EOF

    chmod +x scripts/audit.sh

    # Create maintenance script
    print_status "Creating maintenance script..."
    cat > scripts/maintenance.sh << 'EOF'
#!/bin/bash

# Privacy Architecture Maintenance Script
# This script performs regular maintenance tasks

set -e

echo "Starting Privacy Architecture Maintenance..."

# Clean up old logs
echo "Cleaning up old logs..."
find logs/ -name "*.log" -mtime +30 -delete 2>/dev/null || true

# Clean up old backups
echo "Cleaning up old backups..."
find backups/ -name "*.tar.gz" -mtime +90 -delete 2>/dev/null || true

# Update service data
echo "Updating service data..."
if [ -f "data/services.json" ]; then
    # Add timestamp
    jq '.last_updated = now' data/services.json > data/services.json.tmp
    mv data/services.json.tmp data/services.json
fi

# Check for updates
echo "Checking for updates..."
if [ -f "package.json" ]; then
    npm outdated 2>/dev/null || true
fi

echo "Maintenance completed."
EOF

    chmod +x scripts/maintenance.sh

    # Create migration helper script
    print_status "Creating migration helper script..."
    cat > scripts/migrate-service.sh << 'EOF'
#!/bin/bash

# Privacy Architecture Service Migration Helper
# This script helps migrate services to the privacy architecture

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <service-name>"
    echo "Example: $0 netflix"
    exit 1
fi

SERVICE_NAME="$1"
SERVICE_EMAIL="${SERVICE_NAME}@softmoth.com"
MIGRATION_DATE=$(date +%Y-%m-%d)

echo "Migrating service: $SERVICE_NAME"
echo "Email: $SERVICE_EMAIL"
echo "Date: $MIGRATION_DATE"

# Create migration log entry
if [ -f "data/migration-log.json" ]; then
    jq --arg service "$SERVICE_NAME" --arg email "$SERVICE_EMAIL" --arg date "$MIGRATION_DATE" \
       '.migrations += [{"date": $date, "service": $service, "email": $email, "status": "pending"}]' \
       data/migration-log.json > data/migration-log.json.tmp
    mv data/migration-log.json.tmp data/migration-log.json
fi

echo "Migration entry created. Complete the migration manually and update the status."
EOF

    chmod +x scripts/migrate-service.sh

    # Set permissions
    print_status "Setting permissions..."
    chmod +x scripts/*.sh
    chmod 644 config/templates/*.json
    chmod 644 config/templates/*.conf

    # Create README for scripts
    print_status "Creating scripts README..."
    cat > scripts/README.md << 'EOF'
# Privacy Architecture Scripts

This directory contains utility scripts for managing the privacy architecture.

## Available Scripts

### setup.sh
Initial project setup script. Run this first to create the project structure.

### backup.sh
Backs up all important data including 1Password vault, configuration files, and logs.

### audit.sh
Audits the privacy architecture for common issues and missing components.

### maintenance.sh
Performs regular maintenance tasks like log cleanup and data updates.

### migrate-service.sh
Helper script for migrating services to the privacy architecture.

## Usage

All scripts are executable and can be run directly:

```bash
./scripts/setup.sh
./scripts/backup.sh
./scripts/audit.sh
./scripts/maintenance.sh
./scripts/migrate-service.sh netflix
```

## Requirements

- bash
- jq (for JSON processing)
- curl (for API calls)
- op (1Password CLI, optional)

## Configuration

Scripts use configuration files in the `config/` directory. Make sure to set up your environment variables before running the scripts.
EOF

    print_success "Privacy Architecture setup completed!"
    print_status "Next steps:"
    print_status "1. Copy config/templates/.env.example to config/production/.env"
    print_status "2. Edit config/production/.env with your actual values"
    print_status "3. Run ./scripts/audit.sh to check for issues"
    print_status "4. Start migrating services with ./scripts/migrate-service.sh <service-name>"
}

# Run main function
main "$@"
