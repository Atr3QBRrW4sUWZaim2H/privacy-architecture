# Service Migration Strategy

## Migration Priority

### Critical Services (Save for Later)
- Apple ID (multiple security alerts)
- Banking/Financial services
- Government services
- Employment-related accounts

### Medium Priority (In Progress)
- Uber (active, payment update needed)
- eBay (using Apple Hide My Email)
- Reddit (DontGetEliminated username)
- TripIt Pro (annual, try again later)

### Low Priority (Completed)
- Monarch Budget ✅
- Netflix ✅
- Zoom ✅ (new account ready)
- Spotify (cancelled)
- Peakto (cancelled)
- ChatGPT Business (cancelled)

## Migration Process

### For Each Service
1. **Log into service**
2. **Update email** to servicename@softmoth.com
3. **Enable 2FA** (prefer TOTP in 1Password)
4. **Update payment** to Privacy.com if applicable
5. **Document everything** in 1Password immediately

### Testing Strategy
- Start with low-risk services
- Test full system before critical services
- Verify email forwarding works
- Confirm TOTP codes work
- Test Privacy.com payments

## Service-Specific Notes

### Uber
- **Current Status:** Active, using AmEx for payment
- **Email:** uber@softmoth.com
- **Payment:** Switch to Privacy.com
- **Phone:** Might need Hushed
- **Priority:** Medium (frequently used)

### eBay
- **Current Status:** Using Apple Hide My Email
- **Email:** ebay@softmoth.com (optional)
- **Payment:** Already using Apple Pay
- **Phone:** Not required
- **Priority:** Low (already has some privacy)

### Reddit
- **Current Status:** DontGetEliminated username
- **Email:** reddit@softmoth.com
- **2FA:** Enable if available
- **Payment:** Not required
- **Priority:** Low (no financial risk)

### TripIt Pro
- **Current Status:** Annual subscription, blocked by VPN
- **Email:** tripit@softmoth.com
- **Payment:** Update to Privacy.com
- **Phone:** Not required
- **Priority:** Low (annual, not urgent)

### Apple iCloud+
- **Current Status:** Likely active
- **Email:** apple@softmoth.com
- **2FA:** Critical - use TOTP
- **Payment:** Update to Privacy.com
- **Phone:** May need real number
- **Priority:** High (critical service)

## Migration Checklist

### Pre-Migration
- [ ] Service identified
- [ ] Current credentials documented
- [ ] Backup any important data
- [ ] Check for 2FA options
- [ ] Verify payment requirements

### During Migration
- [ ] Create new email alias
- [ ] Update email in service
- [ ] Enable 2FA (TOTP preferred)
- [ ] Update payment method
- [ ] Test all functionality
- [ ] Document in 1Password

### Post-Migration
- [ ] Verify email forwarding
- [ ] Test 2FA codes
- [ ] Confirm payment works
- [ ] Update any bookmarks
- [ ] Close old account (if applicable)

## Common Issues

### OAuth Sign-in Services
- **Problem:** Many services use "Sign in with Google"
- **Impact:** Can't unlink from Google account
- **Solution:** Create new account with softmoth email
- **Alternative:** Let old OAuth accounts die naturally

### SMS-Only Services
- **Problem:** Some services require SMS for 2FA
- **Impact:** Must use Hushed number
- **Solution:** Document which services need SMS
- **Consideration:** Is service worth the SMS cost?

### Address Verification
- **Problem:** Some services verify billing address
- **Impact:** Must use real or consistent fake address
- **Solution:** Use friend's address or CMRA
- **Consideration:** Keep variations consistent

### Payment Verification
- **Problem:** Some services reject virtual cards
- **Impact:** Must use real credit card
- **Solution:** Try different Privacy.com card
- **Consideration:** Is service worth real payment?

## Migration Timeline

### Week 1: Low-Risk Services
- [ ] Reddit (no financial risk)
- [ ] TripIt Pro (annual, not urgent)
- [ ] Any other low-risk accounts

### Week 2: Medium-Risk Services
- [ ] Uber (frequently used)
- [ ] eBay (optional, already has privacy)
- [ ] Any other medium-risk accounts

### Week 3: High-Risk Services
- [ ] Apple iCloud+ (critical)
- [ ] Any other high-risk accounts

### Week 4: Critical Services
- [ ] Apple ID (most critical)
- [ ] Banking services
- [ ] Government services

## Service Categories

### Financial Services
- **Priority:** High
- **2FA:** TOTP required
- **Payment:** Real cards only
- **Phone:** May need real number
- **Address:** Real address required

### Email/Cloud Services
- **Priority:** High
- **2FA:** TOTP preferred
- **Payment:** Virtual cards OK
- **Phone:** Hushed OK
- **Address:** Fake address OK

### Shopping Services
- **Priority:** Medium
- **2FA:** TOTP if available
- **Payment:** Virtual cards preferred
- **Phone:** Hushed OK
- **Address:** Fake address OK

### Social/Entertainment
- **Priority:** Low
- **2FA:** TOTP if available
- **Payment:** Virtual cards OK
- **Phone:** Hushed OK
- **Address:** Fake address OK

## Risk Assessment

### High Risk
- **Services:** Banking, Apple ID, Government
- **Impact:** Identity theft, financial loss
- **Mitigation:** Real identity only, maximum security
- **Timeline:** Last to migrate

### Medium Risk
- **Services:** Uber, eBay, Cloud storage
- **Impact:** Privacy breach, harassment
- **Mitigation:** Virtual identity, good security
- **Timeline:** Second wave

### Low Risk
- **Services:** Reddit, TripIt, Entertainment
- **Impact:** Minimal
- **Mitigation:** Basic privacy measures
- **Timeline:** First to migrate

## Testing Procedures

### Email Testing
1. Send test email to new alias
2. Verify it arrives in Fastmail
3. Check spam folder
4. Test reply functionality

### 2FA Testing
1. Enable TOTP in service
2. Test code generation in 1Password
3. Verify codes work with service
4. Test backup codes if available

### Payment Testing
1. Create new Privacy.com card
2. Update payment in service
3. Make small test purchase
4. Verify transaction appears

### Phone Testing
1. Add Hushed number to service
2. Request SMS verification
3. Verify code arrives
4. Test multiple times

## Documentation Standards

### 1Password Entry
- **Title:** Service name
- **Username:** Email alias used
- **Password:** Strong, unique password
- **2FA:** TOTP secret or SMS number
- **Notes:** Migration date, special requirements
- **Tags:** Service type, priority level

### Migration Log
- **Date:** When migration completed
- **Service:** Name of service
- **Email:** Alias used
- **2FA:** Method used
- **Payment:** Card used
- **Issues:** Any problems encountered
- **Status:** Success/failure

## Rollback Procedures

### If Migration Fails
1. **Immediate:** Revert to original settings
2. **Document:** What went wrong
3. **Analyze:** Root cause
4. **Plan:** Alternative approach
5. **Retry:** When ready

### If Service Breaks
1. **Check:** Service status
2. **Verify:** Credentials still work
3. **Test:** All functionality
4. **Contact:** Service support if needed
5. **Document:** Resolution

## Success Metrics

### Technical Metrics
- [ ] Email forwarding works
- [ ] 2FA codes generate correctly
- [ ] Payments process successfully
- [ ] All functionality preserved

### Security Metrics
- [ ] No real identity exposed
- [ ] Unique credentials per service
- [ ] Compromised services isolated
- [ ] Audit trail maintained

### Usability Metrics
- [ ] Easy to use daily
- [ ] Quick access to services
- [ ] Clear documentation
- [ ] Reliable operation

---

*This migration strategy provides a systematic approach to moving your services to the privacy architecture while minimizing risk and maintaining functionality.*
