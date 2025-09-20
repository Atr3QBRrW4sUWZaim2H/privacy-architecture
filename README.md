# Privacy Abstraction Layer: Protection Against Malicious Actors

A comprehensive privacy architecture designed to protect individuals from malicious actors (stalkers, doxxers, harassers) by breaking the chain between online activities and real identity.

## 🎯 Project Overview

**Threat Model:** Individual malicious actors seeking to dox, stalk, or harass  
**Goal:** Make yourself too annoying to target effectively  
**Principle:** Break the chain between online activities and real identity

## 🏗️ Architecture Layers

### Layer 1: Foundation Identity (Never Exposed)
- **Real Name:** Government, employer, banking only
- **Real Address:** Government, utilities, critical services only  
- **Real Phone:** Banking, family, emergency contacts only
- **Real Payment:** Utilities, government, salary only

### Layer 2: Service Identity (Database Protection)
- **Email:** Fastmail + softmoth.com domain (unlimited aliases)
- **Phone:** Hushed number for SMS-required services
- **2FA:** 1Password TOTP (preferred over SMS)
- **Payment:** Privacy.com virtual cards
- **Address:** Friend's house or CMRA

### Layer 3: Public Identity (Human Interaction)
- **Email:** Existing Gmail for people you meet
- **Phone:** Second Hushed or Google Voice
- **Social:** Consistent pseudonym
- **Payment:** Gift cards or crypto

## ✅ Implementation Status

### Completed Systems
- [x] **Email System:** Fastmail + softmoth.com domain
- [x] **2FA System:** 1Password TOTP integration
- [x] **Phone System:** Hushed for SMS-required services
- [x] **Payment System:** Privacy.com virtual cards
- [x] **Service Migration:** Monarch, Netflix, Zoom (in progress)

### Active Subscriptions Migrated
- [x] Monarch Budget → monarch@softmoth.com
- [x] Netflix → netflix@softmoth.com  
- [x] Zoom → zoom@softmoth.com (new account, old expires in 2 days)
- [x] Cancelled: Spotify, Peakto, ChatGPT Business

### Remaining Services
- [ ] TripIt Pro (annual, blocked by VPN)
- [ ] Apple iCloud+ (if active)
- [ ] Uber (active, needs migration)
- [ ] eBay (using Apple Hide My Email)
- [ ] Reddit (DontGetEliminated username)

## 💰 Cost Structure

- **Fastmail:** $5/month
- **Hushed:** $5/month (one number)
- **Privacy.com:** Free
- **1Password:** Already have
- **Domain:** $15/year
- **Total:** ~$11/month for comprehensive protection

## 🚀 Quick Start

1. **Email Setup:** Use servicename@softmoth.com for all new accounts
2. **2FA:** Always choose TOTP in 1Password over SMS
3. **Phone:** Use Hushed only when SMS is required
4. **Payment:** Create new Privacy.com card per service
5. **Document:** Save everything in 1Password immediately

## 📚 Documentation

- **[Implementation Guide](docs/implementation.md)** - Step-by-step setup
- **[Migration Strategy](docs/migration.md)** - Service migration process
- **[Security Analysis](docs/security.md)** - Threat model and protections
- **[Cost Analysis](docs/costs.md)** - Detailed cost breakdown
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues

## 🔧 Maintenance

### Daily Practices
- Use unique email per service
- Prefer TOTP over SMS
- Document new accounts immediately
- Block compromised addresses

### Weekly Tasks
- Review new service signups
- Check for any real identity leaks
- Update 1Password entries

### Monthly Tasks
- Review Hushed usage and costs
- Audit Privacy.com card usage
- Check for address verification needs

## 📊 Success Metrics

- [x] Every service has unique email
- [x] Most services use TOTP not SMS
- [x] Real phone number rarely used
- [x] No service has real address
- [x] Everything documented in 1Password

## 🛡️ Security Benefits

- **Email:** Unique per service, instant spam control
- **2FA:** App-based is unhackable via SIM swap
- **Phone:** No real number exposed
- **Payment:** Virtual cards can't be reused
- **Address:** Physical location protected

## 🛠️ Scripts

- **`scripts/setup.sh`** - Initial project setup
- **`scripts/migrate-service.sh`** - Service migration helper
- **`scripts/audit-accounts.sh`** - Account audit and review
- **`scripts/backup-vault.sh`** - 1Password vault backup

## ⚙️ Configuration

### Environment Variables
Copy `.env.example` to `.env` and configure:
```bash
cp .env.example .env
# Edit .env with your settings
```

### Service Configuration
- **Fastmail:** Configured with softmoth.com domain
- **Hushed:** One number for SMS-required services
- **Privacy.com:** Funded and ready for virtual cards
- **1Password:** TOTP integration enabled

## 📊 Project Status

- **Status:** Active Implementation
- **Version:** 2.0.0
- **Last Updated:** 2024-09-19
- **Maintainer:** Privacy Architecture Team

## 🔧 Maintenance

### Regular Tasks
- **Daily:** Use unique emails, prefer TOTP
- **Weekly:** Review new accounts, check for leaks
- **Monthly:** Audit costs, review service usage
- **Quarterly:** Update passwords, review architecture

### Backup Strategy
- **1Password:** Cloud sync with local backup
- **Fastmail:** Built-in backup and recovery
- **Privacy.com:** Transaction history maintained
- **Documentation:** Version controlled in project

## 📞 Support

For issues and questions:
1. Check [troubleshooting guide](docs/troubleshooting.md)
2. Review [implementation guide](docs/implementation.md)
3. Check project logs in `logs/` directory
4. Review service-specific documentation

---

*This privacy architecture provides comprehensive protection against malicious actors while maintaining usability for legitimate services.*
