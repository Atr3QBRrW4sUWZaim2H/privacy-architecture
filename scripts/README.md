# Privacy Architecture Scripts

This directory contains utility scripts for managing the privacy architecture.

## Available Scripts

### setup.sh
Initial project setup script. Run this first to create the project structure.

**Usage:**
```bash
./scripts/setup.sh
```

**Features:**
- Creates project directory structure
- Sets up configuration templates
- Creates data files
- Sets up log files
- Creates backup files
- Sets up environment templates
- Creates utility scripts

### backup.sh
Backs up all important data including 1Password vault, configuration files, and logs.

**Usage:**
```bash
./scripts/backup.sh
```

**Features:**
- Backs up 1Password vault (if CLI available)
- Backs up configuration files
- Backs up data files
- Backs up logs
- Backs up documentation
- Creates backup manifest
- Compresses backup into archive
- Cleans up old backups (keeps last 10)

### audit.sh
Audits the privacy architecture for common issues and missing components.

**Usage:**
```bash
./scripts/audit.sh
```

**Features:**
- Checks required tools
- Verifies project structure
- Checks configuration files
- Checks data files
- Checks documentation files
- Checks script files
- Checks permissions
- Checks for common issues
- Generates audit report

### maintenance.sh
Performs regular maintenance tasks like log cleanup and data updates.

**Usage:**
```bash
./scripts/maintenance.sh
```

**Features:**
- Cleans up old logs (30+ days)
- Cleans up old backups (90+ days)
- Updates service data
- Updates migration log
- Updates cost tracking
- Checks for updates
- Checks disk usage
- Checks log file sizes
- Checks backup file sizes
- Checks for security issues
- Generates maintenance report

### migrate-service.sh
Helper script for migrating services to the privacy architecture.

**Usage:**
```bash
./scripts/migrate-service.sh <service-name> [options]
```

**Options:**
- `-e, --email <email>` - Custom email address (default: servicename@softmoth.com)
- `-p, --phone <phone>` - Phone number to use (default: Hushed number)
- `-c, --card <card>` - Privacy.com card to use
- `-s, --status <status>` - Initial status (default: pending)
- `-h, --help` - Show help message

**Examples:**
```bash
./scripts/migrate-service.sh netflix
./scripts/migrate-service.sh uber --email uber@softmoth.com --status completed
./scripts/migrate-service.sh reddit --phone +1234567890
```

**Features:**
- Creates migration log entry
- Creates service-specific notes
- Creates 1Password entry template
- Displays migration checklist
- Provides next steps guidance

## Requirements

### Required Tools
- **bash** - Shell interpreter
- **jq** - JSON processing (for data manipulation)
- **curl** - API calls (for external services)
- **tar** - Archive creation (for backups)
- **find** - File searching (for cleanup)

### Optional Tools
- **op** - 1Password CLI (for vault backup)
- **npm** - Node.js package manager (for package updates)
- **df** - Disk usage checking

## Configuration

Scripts use configuration files in the `config/` directory. Make sure to set up your environment variables before running the scripts.

### Environment Setup
1. Copy `config/templates/.env.example` to `config/production/.env`
2. Edit `config/production/.env` with your actual values
3. Run `./scripts/audit.sh` to check for issues

### Data Files
Scripts create and maintain several data files:
- `data/services.json` - Service configuration
- `data/migration-log.json` - Migration tracking
- `data/cost-tracking.json` - Cost monitoring

## Usage Patterns

### Initial Setup
```bash
# 1. Run setup script
./scripts/setup.sh

# 2. Configure environment
cp config/templates/.env.example config/production/.env
# Edit config/production/.env with your values

# 3. Run audit
./scripts/audit.sh

# 4. Start migrating services
./scripts/migrate-service.sh netflix
```

### Daily Operations
```bash
# Check system health
./scripts/audit.sh

# Migrate a new service
./scripts/migrate-service.sh uber
```

### Weekly Maintenance
```bash
# Run maintenance tasks
./scripts/maintenance.sh

# Create backup
./scripts/backup.sh
```

### Monthly Review
```bash
# Full audit
./scripts/audit.sh

# Maintenance
./scripts/maintenance.sh

# Backup
./scripts/backup.sh
```

## Troubleshooting

### Common Issues

#### Permission Denied
```bash
chmod +x scripts/*.sh
```

#### jq Not Found
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# CentOS/RHEL
sudo yum install jq
```

#### 1Password CLI Not Found
```bash
# Install 1Password CLI
# See: https://developer.1password.com/docs/cli/get-started
```

#### Script Fails
1. Check error messages
2. Verify file permissions
3. Check required tools
4. Review configuration files
5. Run audit script

### Debug Mode
Add `set -x` to any script to enable debug mode:
```bash
#!/bin/bash
set -x
# ... rest of script
```

### Log Files
Scripts create log files in the `logs/` directory:
- `logs/setup.log` - Setup script logs
- `logs/migration.log` - Migration logs
- `logs/audit.log` - Audit logs
- `logs/maintenance.log` - Maintenance logs
- `logs/errors.log` - Error logs

## Customization

### Adding New Scripts
1. Create script in `scripts/` directory
2. Make it executable: `chmod +x scripts/new-script.sh`
3. Add documentation to this README
4. Test with audit script

### Modifying Existing Scripts
1. Make changes to script
2. Test thoroughly
3. Update documentation
4. Run audit script
5. Commit changes

### Configuration Changes
1. Update templates in `config/templates/`
2. Update production configs
3. Test with audit script
4. Document changes

## Security Considerations

### File Permissions
- Scripts should be executable by owner only
- Configuration files should not be world-readable
- Log files should be readable by owner only

### Sensitive Data
- Never hardcode credentials in scripts
- Use environment variables for sensitive data
- Keep configuration files secure
- Regular security audits

### Backup Security
- Encrypt backup files if needed
- Store backups securely
- Regular backup testing
- Secure backup access

## Contributing

### Code Style
- Use consistent indentation (2 spaces)
- Add comments for complex logic
- Use descriptive variable names
- Follow bash best practices

### Testing
- Test all scripts before committing
- Run audit script after changes
- Test error conditions
- Verify output format

### Documentation
- Update this README for changes
- Document new features
- Include usage examples
- Keep troubleshooting current

---

*This README provides comprehensive documentation for all privacy architecture scripts. Keep it updated as you add new scripts or modify existing ones.*
