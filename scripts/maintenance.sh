#!/bin/bash

# Privacy Architecture Maintenance Script
# This script performs regular maintenance tasks

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

print_status "Starting Privacy Architecture Maintenance..."

# Clean up old logs
print_status "Cleaning up old logs..."
if [ -d "logs" ]; then
    OLD_LOGS=$(find logs/ -name "*.log" -mtime +30 2>/dev/null | wc -l)
    if [ "$OLD_LOGS" -gt 0 ]; then
        find logs/ -name "*.log" -mtime +30 -delete 2>/dev/null || true
        print_success "Removed $OLD_LOGS old log files"
    else
        print_status "No old log files to clean up"
    fi
else
    print_warning "Logs directory not found"
fi

# Clean up old backups
print_status "Cleaning up old backups..."
if [ -d "backups" ]; then
    OLD_BACKUPS=$(find backups/ -name "*.tar.gz" -mtime +90 2>/dev/null | wc -l)
    if [ "$OLD_BACKUPS" -gt 0 ]; then
        find backups/ -name "*.tar.gz" -mtime +90 -delete 2>/dev/null || true
        print_success "Removed $OLD_BACKUPS old backup files"
    else
        print_status "No old backup files to clean up"
    fi
else
    print_warning "Backups directory not found"
fi

# Update service data
print_status "Updating service data..."
if [ -f "data/services.json" ]; then
    if command -v jq >/dev/null 2>&1; then
        # Add timestamp
        jq '.last_updated = now' data/services.json > data/services.json.tmp
        mv data/services.json.tmp data/services.json
        print_success "Service data updated with timestamp"
    else
        print_warning "jq not found - skipping service data update"
    fi
else
    print_warning "Services data file not found"
fi

# Update migration log
print_status "Updating migration log..."
if [ -f "data/migration-log.json" ]; then
    if command -v jq >/dev/null 2>&1; then
        # Update statistics
        TOTAL_MIGRATED=$(jq '.migrations | length' data/migration-log.json)
        SUCCESSFUL=$(jq '[.migrations[] | select(.status == "completed")] | length' data/migration-log.json)
        FAILED=$(jq '[.migrations[] | select(.status == "failed")] | length' data/migration-log.json)
        PENDING=$(jq '[.migrations[] | select(.status == "pending")] | length' data/migration-log.json)
        
        jq --arg total "$TOTAL_MIGRATED" --arg successful "$SUCCESSFUL" --arg failed "$FAILED" --arg pending "$PENDING" \
           '.statistics = {"total_migrated": ($total | tonumber), "successful": ($successful | tonumber), "failed": ($failed | tonumber), "pending": ($pending | tonumber)}' \
           data/migration-log.json > data/migration-log.json.tmp
        mv data/migration-log.json.tmp data/migration-log.json
        print_success "Migration log statistics updated"
    else
        print_warning "jq not found - skipping migration log update"
    fi
else
    print_warning "Migration log not found"
fi

# Update cost tracking
print_status "Updating cost tracking..."
if [ -f "data/cost-tracking.json" ]; then
    if command -v jq >/dev/null 2>&1; then
        # Update last updated timestamp
        jq '.tracking.last_updated = now' data/cost-tracking.json > data/cost-tracking.json.tmp
        mv data/cost-tracking.json.tmp data/cost-tracking.json
        print_success "Cost tracking updated with timestamp"
    else
        print_warning "jq not found - skipping cost tracking update"
    fi
else
    print_warning "Cost tracking file not found"
fi

# Check for updates
print_status "Checking for updates..."
if [ -f "package.json" ]; then
    if command -v npm >/dev/null 2>&1; then
        print_status "Checking npm packages for updates..."
        npm outdated 2>/dev/null || print_warning "Some packages may have updates available"
    else
        print_warning "npm not found - skipping package update check"
    fi
else
    print_status "No package.json found - skipping package update check"
fi

# Check disk usage
print_status "Checking disk usage..."
if command -v df >/dev/null 2>&1; then
    DISK_USAGE=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 80 ]; then
        print_warning "Disk usage is high: ${DISK_USAGE}%"
    else
        print_success "Disk usage is normal: ${DISK_USAGE}%"
    fi
else
    print_warning "df command not found - skipping disk usage check"
fi

# Check log file sizes
print_status "Checking log file sizes..."
if [ -d "logs" ]; then
    LARGE_LOGS=$(find logs -name "*.log" -size +10M 2>/dev/null)
    if [ -n "$LARGE_LOGS" ]; then
        print_warning "Large log files found:"
        echo "$LARGE_LOGS" | while read -r log; do
            SIZE=$(du -h "$log" | cut -f1)
            print_warning "  $log ($SIZE)"
        done
        print_status "Consider running log rotation or manual cleanup"
    else
        print_success "No large log files found"
    fi
else
    print_warning "Logs directory not found"
fi

# Check backup file sizes
print_status "Checking backup file sizes..."
if [ -d "backups" ]; then
    BACKUP_COUNT=$(find backups -name "*.tar.gz" 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 0 ]; then
        TOTAL_BACKUP_SIZE=$(find backups -name "*.tar.gz" -exec du -ch {} + 2>/dev/null | tail -1 | cut -f1)
        print_success "Found $BACKUP_COUNT backup files (total: $TOTAL_BACKUP_SIZE)"
    else
        print_warning "No backup files found - consider running backup.sh"
    fi
else
    print_warning "Backups directory not found"
fi

# Check for security issues
print_status "Checking for security issues..."
if [ -d "config" ]; then
    # Check for world-readable sensitive files
    SENSITIVE_FILES=$(find config -name "*.env" -perm -004 2>/dev/null)
    if [ -n "$SENSITIVE_FILES" ]; then
        print_warning "World-readable sensitive files found:"
        echo "$SENSITIVE_FILES" | while read -r file; do
            print_warning "  $file"
        done
        print_status "Consider changing permissions: chmod 600 <file>"
    else
        print_success "No world-readable sensitive files found"
    fi
else
    print_warning "Config directory not found"
fi

# Generate maintenance report
print_status "Generating maintenance report..."
MAINTENANCE_LOG="logs/maintenance-$(date +%Y%m%d).log"
mkdir -p logs

cat > "$MAINTENANCE_LOG" << EOF
Privacy Architecture Maintenance Report
Date: $(date)
Version: 2.0.0

Maintenance Tasks Completed:
- Log cleanup
- Backup cleanup
- Service data update
- Migration log update
- Cost tracking update
- Package update check
- Disk usage check
- Log file size check
- Backup file size check
- Security check

Report generated by: maintenance.sh
EOF

print_success "Maintenance report generated: $MAINTENANCE_LOG"

# Final summary
print_status "Maintenance completed successfully!"
print_status "Next maintenance recommended in 1 week"
print_status "Run ./scripts/audit.sh to check for any issues"
