#!/bin/bash

# Privacy Architecture Service Migration Helper
# This script helps migrate services to the privacy architecture

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

# Function to show usage
show_usage() {
    echo "Usage: $0 <service-name> [options]"
    echo ""
    echo "Options:"
    echo "  -e, --email <email>     Custom email address (default: servicename@softmoth.com)"
    echo "  -p, --phone <phone>     Phone number to use (default: Hushed number)"
    echo "  -c, --card <card>       Privacy.com card to use"
    echo "  -s, --status <status>   Initial status (default: pending)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 netflix"
    echo "  $0 uber --email uber@softmoth.com --status completed"
    echo "  $0 reddit --phone +1234567890"
}

# Parse command line arguments
SERVICE_NAME=""
SERVICE_EMAIL=""
SERVICE_PHONE=""
SERVICE_CARD=""
SERVICE_STATUS="pending"

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--email)
            SERVICE_EMAIL="$2"
            shift 2
            ;;
        -p|--phone)
            SERVICE_PHONE="$2"
            shift 2
            ;;
        -c|--card)
            SERVICE_CARD="$2"
            shift 2
            ;;
        -s|--status)
            SERVICE_STATUS="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$SERVICE_NAME" ]; then
                SERVICE_NAME="$1"
            else
                print_error "Multiple service names provided"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if service name is provided
if [ -z "$SERVICE_NAME" ]; then
    print_error "Service name is required"
    show_usage
    exit 1
fi

# Set default email if not provided
if [ -z "$SERVICE_EMAIL" ]; then
    SERVICE_EMAIL="${SERVICE_NAME}@softmoth.com"
fi

# Set default phone if not provided
if [ -z "$SERVICE_PHONE" ]; then
    SERVICE_PHONE="Hushed number"
fi

# Set default card if not provided
if [ -z "$SERVICE_CARD" ]; then
    SERVICE_CARD="Privacy.com card"
fi

MIGRATION_DATE=$(date +%Y-%m-%d)

print_status "Migrating service: $SERVICE_NAME"
print_status "Email: $SERVICE_EMAIL"
print_status "Phone: $SERVICE_PHONE"
print_status "Card: $SERVICE_CARD"
print_status "Status: $SERVICE_STATUS"
print_status "Date: $MIGRATION_DATE"

# Create migration log entry
print_status "Creating migration log entry..."
if [ ! -f "data/migration-log.json" ]; then
    # Create initial migration log
    cat > data/migration-log.json << EOF
{
  "migrations": [],
  "statistics": {
    "total_migrated": 0,
    "successful": 0,
    "failed": 0,
    "pending": 0
  }
}
EOF
    print_success "Created migration log file"
fi

# Add migration entry
if command -v jq >/dev/null 2>&1; then
    jq --arg service "$SERVICE_NAME" \
       --arg email "$SERVICE_EMAIL" \
       --arg phone "$SERVICE_PHONE" \
       --arg card "$SERVICE_CARD" \
       --arg status "$SERVICE_STATUS" \
       --arg date "$MIGRATION_DATE" \
       '.migrations += [{"date": $date, "service": $service, "email": $email, "phone": $phone, "card": $card, "status": $status, "notes": ""}]' \
       data/migration-log.json > data/migration-log.json.tmp
    mv data/migration-log.json.tmp data/migration-log.json
    print_success "Migration entry added to log"
else
    print_warning "jq not found - migration entry not added to log"
fi

# Create service-specific notes
print_status "Creating service-specific notes..."
SERVICE_NOTES="data/${SERVICE_NAME}-notes.txt"
cat > "$SERVICE_NOTES" << EOF
Service Migration Notes: $SERVICE_NAME
Date: $MIGRATION_DATE
Email: $SERVICE_EMAIL
Phone: $SERVICE_PHONE
Card: $SERVICE_CARD
Status: $SERVICE_STATUS

Migration Steps:
1. [ ] Log into $SERVICE_NAME
2. [ ] Update email to $SERVICE_EMAIL
3. [ ] Enable 2FA (prefer TOTP in 1Password)
4. [ ] Update payment to $SERVICE_CARD
5. [ ] Update phone to $SERVICE_PHONE (if required)
6. [ ] Test all functionality
7. [ ] Document in 1Password
8. [ ] Update migration status

Notes:
- Add any specific requirements or issues here
- Document any special steps needed
- Record any problems encountered

Next Steps:
- Complete the migration steps above
- Update status when complete
- Remove this file when migration is done
EOF

print_success "Service notes created: $SERVICE_NOTES"

# Create 1Password entry template
print_status "Creating 1Password entry template..."
ONEPASSWORD_TEMPLATE="data/${SERVICE_NAME}-1password.txt"
cat > "$ONEPASSWORD_TEMPLATE" << EOF
1Password Entry Template: $SERVICE_NAME

Title: $SERVICE_NAME
Username: $SERVICE_EMAIL
Password: [Generate strong password]
2FA: [Add TOTP secret if available]
Notes: 
- Migrated on $MIGRATION_DATE
- Email: $SERVICE_EMAIL
- Phone: $SERVICE_PHONE
- Card: $SERVICE_CARD
- Status: $SERVICE_STATUS

Tags: privacy-architecture, migrated, $SERVICE_STATUS
EOF

print_success "1Password template created: $ONEPASSWORD_TEMPLATE"

# Display migration checklist
print_status "Migration checklist for $SERVICE_NAME:"
echo ""
echo "1. [ ] Log into $SERVICE_NAME"
echo "2. [ ] Update email to $SERVICE_EMAIL"
echo "3. [ ] Enable 2FA (prefer TOTP in 1Password)"
echo "4. [ ] Update payment to $SERVICE_CARD"
echo "5. [ ] Update phone to $SERVICE_PHONE (if required)"
echo "6. [ ] Test all functionality"
echo "7. [ ] Document in 1Password"
echo "8. [ ] Update migration status"
echo ""

# Display next steps
print_status "Next steps:"
print_status "1. Complete the migration steps above"
print_status "2. Update status with: $0 $SERVICE_NAME --status completed"
print_status "3. Review service notes: $SERVICE_NOTES"
print_status "4. Use 1Password template: $ONEPASSWORD_TEMPLATE"
print_status "5. Run audit: ./scripts/audit.sh"

print_success "Service migration setup completed for $SERVICE_NAME!"
