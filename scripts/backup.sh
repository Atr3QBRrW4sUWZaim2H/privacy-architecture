#!/bin/bash

# Privacy Architecture Backup Script
# This script backs up all important data

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory
cd "$PROJECT_DIR"

# Create backup directory
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

print_status "Starting backup to $BACKUP_DIR..."

# Backup 1Password vault (if accessible)
if command -v op >/dev/null 2>&1; then
    print_status "Backing up 1Password vault..."
    if op export --format=json > "$BACKUP_DIR/1password-vault.json" 2>/dev/null; then
        print_success "1Password vault backed up"
    else
        print_warning "1Password backup failed - make sure you're signed in"
    fi
else
    print_warning "1Password CLI not found - skipping vault backup"
fi

# Backup configuration files
print_status "Backing up configuration files..."
if [ -d "config" ]; then
    cp -r config/ "$BACKUP_DIR/"
    print_success "Configuration files backed up"
else
    print_warning "Configuration directory not found"
fi

# Backup data files
print_status "Backing up data files..."
if [ -d "data" ]; then
    cp -r data/ "$BACKUP_DIR/"
    print_success "Data files backed up"
else
    print_warning "Data directory not found"
fi

# Backup logs
print_status "Backing up logs..."
if [ -d "logs" ]; then
    cp -r logs/ "$BACKUP_DIR/"
    print_success "Logs backed up"
else
    print_warning "Logs directory not found"
fi

# Backup documentation
print_status "Backing up documentation..."
if [ -d "docs" ]; then
    cp -r docs/ "$BACKUP_DIR/"
    print_success "Documentation backed up"
else
    print_warning "Documentation directory not found"
fi

# Create backup manifest
print_status "Creating backup manifest..."
cat > "$BACKUP_DIR/manifest.txt" << EOF
Privacy Architecture Backup
Date: $(date)
Version: 2.0.0
Backup Directory: $BACKUP_DIR

Contents:
- Configuration files
- Data files
- Log files
- Documentation
- 1Password vault (if available)

Created by: backup.sh
EOF

# Create archive
print_status "Creating backup archive..."
if tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR" 2>/dev/null; then
    print_success "Backup archive created: $BACKUP_DIR.tar.gz"
    rm -rf "$BACKUP_DIR"
    print_status "Temporary directory cleaned up"
else
    print_error "Failed to create backup archive"
    exit 1
fi

# Clean up old backups (keep last 10)
print_status "Cleaning up old backups..."
BACKUP_COUNT=$(ls -1 backups/*.tar.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 10 ]; then
    OLD_BACKUPS=$(ls -1t backups/*.tar.gz | tail -n +11)
    for backup in $OLD_BACKUPS; do
        rm -f "$backup"
        print_status "Removed old backup: $(basename "$backup")"
    done
fi

print_success "Backup completed successfully!"
print_status "Backup location: $BACKUP_DIR.tar.gz"
print_status "Backup size: $(du -h "$BACKUP_DIR.tar.gz" | cut -f1)"
