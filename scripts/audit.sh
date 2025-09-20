#!/bin/bash

# Privacy Architecture Audit Script
# This script audits the privacy architecture for issues

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

print_status "Starting Privacy Architecture Audit..."

# Initialize counters
ERRORS=0
WARNINGS=0
SUCCESSES=0

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check file exists
file_exists() {
    [ -f "$1" ]
}

# Function to check directory exists
dir_exists() {
    [ -d "$1" ]
}

# Check required tools
print_status "Checking required tools..."
if command_exists op; then
    print_success "1Password CLI found"
    ((SUCCESSES++))
else
    print_warning "1Password CLI not found - some features may not work"
    ((WARNINGS++))
fi

if command_exists curl; then
    print_success "curl found"
    ((SUCCESSES++))
else
    print_warning "curl not found - API calls may not work"
    ((WARNINGS++))
fi

if command_exists jq; then
    print_success "jq found"
    ((SUCCESSES++))
else
    print_warning "jq not found - JSON processing may not work"
    ((WARNINGS++))
fi

# Check project structure
print_status "Checking project structure..."
if dir_exists "docs"; then
    print_success "Documentation directory exists"
    ((SUCCESSES++))
else
    print_error "Documentation directory missing"
    ((ERRORS++))
fi

if dir_exists "scripts"; then
    print_success "Scripts directory exists"
    ((SUCCESSES++))
else
    print_error "Scripts directory missing"
    ((ERRORS++))
fi

if dir_exists "config"; then
    print_success "Configuration directory exists"
    ((SUCCESSES++))
else
    print_error "Configuration directory missing"
    ((ERRORS++))
fi

if dir_exists "data"; then
    print_success "Data directory exists"
    ((SUCCESSES++))
else
    print_error "Data directory missing"
    ((ERRORS++))
fi

if dir_exists "logs"; then
    print_success "Logs directory exists"
    ((SUCCESSES++))
else
    print_error "Logs directory missing"
    ((ERRORS++))
fi

if dir_exists "backups"; then
    print_success "Backups directory exists"
    ((SUCCESSES++))
else
    print_error "Backups directory missing"
    ((ERRORS++))
fi

# Check configuration files
print_status "Checking configuration files..."
if file_exists "config/production/.env"; then
    print_success "Production environment file exists"
    ((SUCCESSES++))
else
    print_warning "Production environment file not found - copy from template"
    ((WARNINGS++))
fi

if file_exists "config/development/.env"; then
    print_success "Development environment file exists"
    ((SUCCESSES++))
else
    print_warning "Development environment file not found - copy from template"
    ((WARNINGS++))
fi

if file_exists "config/templates/.env.example"; then
    print_success "Environment template exists"
    ((SUCCESSES++))
else
    print_error "Environment template missing"
    ((ERRORS++))
fi

# Check data files
print_status "Checking data files..."
if file_exists "data/services.json"; then
    print_success "Services data file exists"
    ((SUCCESSES++))
else
    print_warning "Services data file not found - will be created on first run"
    ((WARNINGS++))
fi

if file_exists "data/migration-log.json"; then
    print_success "Migration log exists"
    ((SUCCESSES++))
else
    print_warning "Migration log not found - will be created on first run"
    ((WARNINGS++))
fi

if file_exists "data/cost-tracking.json"; then
    print_success "Cost tracking file exists"
    ((SUCCESSES++))
else
    print_warning "Cost tracking file not found - will be created on first run"
    ((WARNINGS++))
fi

# Check documentation files
print_status "Checking documentation files..."
if file_exists "README.md"; then
    print_success "Main README exists"
    ((SUCCESSES++))
else
    print_error "Main README missing"
    ((ERRORS++))
fi

if file_exists "docs/implementation.md"; then
    print_success "Implementation guide exists"
    ((SUCCESSES++))
else
    print_error "Implementation guide missing"
    ((ERRORS++))
fi

if file_exists "docs/migration.md"; then
    print_success "Migration strategy exists"
    ((SUCCESSES++))
else
    print_error "Migration strategy missing"
    ((ERRORS++))
fi

if file_exists "docs/security.md"; then
    print_success "Security analysis exists"
    ((SUCCESSES++))
else
    print_error "Security analysis missing"
    ((ERRORS++))
fi

if file_exists "docs/costs.md"; then
    print_success "Cost analysis exists"
    ((SUCCESSES++))
else
    print_error "Cost analysis missing"
    ((ERRORS++))
fi

if file_exists "docs/troubleshooting.md"; then
    print_success "Troubleshooting guide exists"
    ((SUCCESSES++))
else
    print_error "Troubleshooting guide missing"
    ((ERRORS++))
fi

# Check script files
print_status "Checking script files..."
if file_exists "scripts/setup.sh"; then
    print_success "Setup script exists"
    ((SUCCESSES++))
else
    print_error "Setup script missing"
    ((ERRORS++))
fi

if file_exists "scripts/backup.sh"; then
    print_success "Backup script exists"
    ((SUCCESSES++))
else
    print_error "Backup script missing"
    ((ERRORS++))
fi

if file_exists "scripts/audit.sh"; then
    print_success "Audit script exists"
    ((SUCCESSES++))
else
    print_error "Audit script missing"
    ((ERRORS++))
fi

# Check script permissions
print_status "Checking script permissions..."
for script in scripts/*.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_success "Script $(basename "$script") is executable"
            ((SUCCESSES++))
        else
            print_warning "Script $(basename "$script") is not executable"
            ((WARNINGS++))
        fi
    fi
done

# Check log files
print_status "Checking log files..."
if dir_exists "logs" && [ "$(ls -A logs 2>/dev/null)" ]; then
    print_success "Log files exist"
    ((SUCCESSES++))
else
    print_warning "No log files found - this is normal for new installations"
    ((WARNINGS++))
fi

# Check backup files
print_status "Checking backup files..."
if dir_exists "backups" && [ "$(ls -A backups 2>/dev/null)" ]; then
    print_success "Backup files exist"
    ((SUCCESSES++))
else
    print_warning "No backup files found - run backup.sh to create backups"
    ((WARNINGS++))
fi

# Check for common issues
print_status "Checking for common issues..."

# Check for hardcoded credentials
if grep -r "password\|secret\|key" config/ 2>/dev/null | grep -v ".env.example" | grep -v "template" >/dev/null; then
    print_warning "Potential hardcoded credentials found in config files"
    ((WARNINGS++))
fi

# Check for missing .env files
if [ ! -f "config/production/.env" ] && [ ! -f "config/development/.env" ]; then
    print_warning "No environment files found - copy from templates"
    ((WARNINGS++))
fi

# Check for large log files
if dir_exists "logs"; then
    LARGE_LOGS=$(find logs -name "*.log" -size +10M 2>/dev/null | wc -l)
    if [ "$LARGE_LOGS" -gt 0 ]; then
        print_warning "Large log files found - consider log rotation"
        ((WARNINGS++))
    fi
fi

# Check for old backups
if dir_exists "backups"; then
    OLD_BACKUPS=$(find backups -name "*.tar.gz" -mtime +30 2>/dev/null | wc -l)
    if [ "$OLD_BACKUPS" -gt 0 ]; then
        print_warning "Old backup files found - consider cleanup"
        ((WARNINGS++))
    fi
fi

# Summary
print_status "Audit completed!"
echo ""
print_status "Summary:"
print_success "Successes: $SUCCESSES"
print_warning "Warnings: $WARNINGS"
print_error "Errors: $ERRORS"

if [ "$ERRORS" -gt 0 ]; then
    print_error "Audit failed with $ERRORS errors"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    print_warning "Audit completed with $WARNINGS warnings"
    exit 0
else
    print_success "Audit passed with no issues"
    exit 0
fi
