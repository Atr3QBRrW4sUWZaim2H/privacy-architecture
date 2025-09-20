# Implementation Guide

## Phase 1: Email System ✅ COMPLETE

### Fastmail + softmoth.com Setup
- **Base email:** Never shared with anyone
- **Unlimited aliases:** anything@softmoth.com works instantly
- **No categories needed:** Just use servicename@softmoth.com

### Examples
- amazon@softmoth.com
- netflix@softmoth.com
- chase@softmoth.com

## Phase 2: Authentication ✅ COMPLETE

### 1Password TOTP Integration
- Already have it for passwords
- Add TOTP codes to existing entries
- Avoid SMS whenever possible

### Hushed Setup
- Buy one number (~$5/month)
- Use for services that require SMS
- Pay with Privacy.com card

### Migration Priority
1. Financial: Convert to TOTP
2. Email/Cloud: Convert to TOTP
3. Shopping: Use TOTP if available
4. Only use SMS when no choice

## Phase 3: Payment Isolation ✅ COMPLETE

### Privacy.com Setup
- Fund with bank account
- Create cards by category
- Use fake billing addresses
- Set spending limits

### Card Strategy
- New card per service
- Burn if compromised
- Document in 1Password

## Phase 4: Address Protection (Pending)

### Option A: Friend's Address (Recommended)
- Most convenient if available
- Offer to pay them monthly
- Use variations (Apt B, etc.)

### Option B: CMRA/PMB (If needed)
- UPS Store as last resort
- More formal but less convenient

## Daily Security Practices

### Email Usage
- Never give base Fastmail address
- Always create service@softmoth.com
- If spam: Block that specific address
- Document: Save in 1Password with account

### Phone Usage
- Prefer TOTP in 1Password over SMS
- Hushed only when SMS required
- Real number only for government/bank
- Let Hushed expire if not needed

### New Service Signup
- Email: servicename@softmoth.com
- Phone: TOTP preferred, Hushed if SMS required
- Payment: New Privacy.com card
- Address: Friend's or CMRA
- Document everything in 1Password

## Quick Reference

When signing up for anything:
- Email: servicename@softmoth.com
- 2FA: Choose app-based (TOTP) in 1Password
- Phone: Only if required, use Hushed
- Payment: New Privacy.com card
- Address: Friend's house
- Save: Everything in 1Password

If something gets compromised:
- Email: Block that address in Fastmail
- Card: Cancel in Privacy.com
- Phone: Let Hushed number expire
- Update: Service with new details

## Service-Specific Implementation

### Email Services
1. **Fastmail Configuration**
   - Domain: softmoth.com
   - Aliases: Unlimited
   - Spam filtering: Enabled
   - Backup: Built-in

2. **Alias Management**
   - Pattern: servicename@softmoth.com
   - No pre-creation needed
   - Instant activation
   - Easy blocking

### 2FA Services
1. **1Password TOTP**
   - Add to existing entries
   - Scan QR codes
   - Test immediately
   - Document in notes

2. **Hushed SMS**
   - Only when TOTP unavailable
   - Document which services need it
   - Monitor usage and costs
   - Consider alternatives

### Payment Services
1. **Privacy.com Cards**
   - Create per service
   - Set spending limits
   - Use fake billing addresses
   - Monitor transactions

2. **Card Management**
   - Burn if compromised
   - Create new ones easily
   - Track usage patterns
   - Document in 1Password

## Implementation Checklist

### Initial Setup
- [ ] Fastmail account with softmoth.com domain
- [ ] 1Password with TOTP capability
- [ ] Hushed account with one number
- [ ] Privacy.com account funded
- [ ] 1Password vault organized

### Service Migration
- [ ] Identify all existing accounts
- [ ] Prioritize by importance
- [ ] Start with low-risk services
- [ ] Test each migration thoroughly
- [ ] Document everything in 1Password

### Ongoing Maintenance
- [ ] Use unique emails for new services
- [ ] Prefer TOTP over SMS
- [ ] Create new Privacy.com cards as needed
- [ ] Block compromised addresses immediately
- [ ] Regular 1Password vault review

## Troubleshooting Common Issues

### Email Not Working
- Check spelling of email address
- Verify Fastmail configuration
- Check spam folder
- Test with simple email first

### TOTP Not Working
- Check time sync on device
- Verify secret key in 1Password
- Try manual entry
- Contact service support

### SMS Required
- Use Hushed number
- Document which services need it
- Consider if service is worth SMS cost
- Look for TOTP alternatives

### Payment Issues
- Check Privacy.com balance
- Verify card limits
- Try different card
- Use real billing address if required

## Security Best Practices

### Password Management
- Use 1Password for everything
- Generate strong passwords
- Enable 2FA on 1Password
- Regular vault backups

### Email Security
- Never reuse email addresses
- Block compromised addresses immediately
- Use aliases for everything
- Monitor for spam

### Phone Security
- Prefer TOTP over SMS
- Use Hushed only when necessary
- Keep real number private
- Monitor usage and costs

### Payment Security
- Use virtual cards for everything
- Set appropriate spending limits
- Monitor transactions regularly
- Burn compromised cards immediately

## Advanced Configuration

### 1Password Organization
- Use folders for different service types
- Add tags for easy searching
- Include notes with migration dates
- Regular cleanup of old entries

### Fastmail Rules
- Set up automatic forwarding
- Configure spam filtering
- Create email templates
- Monitor usage patterns

### Privacy.com Optimization
- Group cards by service type
- Set appropriate limits
- Use descriptive names
- Regular audit of unused cards

## Monitoring and Alerts

### Daily Monitoring
- Check for new emails
- Review 1Password entries
- Monitor Privacy.com transactions
- Check for any security alerts

### Weekly Review
- Audit new service signups
- Check for identity leaks
- Review spending patterns
- Update documentation

### Monthly Audit
- Review all active services
- Check for unused accounts
- Optimize costs
- Update security measures

## Success Metrics

### Implementation Goals
- [ ] All services use unique emails
- [ ] Most services use TOTP
- [ ] Real phone number rarely used
- [ ] All payments use virtual cards
- [ ] Everything documented in 1Password

### Security Goals
- [ ] No real identity exposed
- [ ] Compromised services easily isolated
- [ ] Quick recovery from breaches
- [ ] Minimal attack surface
- [ ] Comprehensive audit trail

### Usability Goals
- [ ] Easy to use daily
- [ ] Quick service signup
- [ ] Simple maintenance
- [ ] Clear documentation
- [ ] Reliable operation

---

*This implementation guide provides step-by-step instructions for setting up and maintaining your privacy architecture.*
