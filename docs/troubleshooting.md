# Troubleshooting Guide

## Common Issues

### Email Issues

#### Email Not Forwarding
**Symptoms:** Messages sent to servicename@softmoth.com not appearing in Fastmail
**Causes:**
- Typo in email address
- Service hasn't sent email yet
- Spam filter blocking
- Fastmail configuration issue

**Solutions:**
1. Double-check email address spelling
2. Check spam folder in Fastmail
3. Verify Fastmail alias configuration
4. Test with a simple email first

#### Spam in Inbox
**Symptoms:** Unwanted emails appearing in Fastmail inbox
**Causes:**
- Email address compromised
- Service sold email to third parties
- Spam filter not working

**Solutions:**
1. Block the specific email address in Fastmail
2. Create new email address for that service
3. Update service with new email
4. Document in 1Password

### 2FA Issues

#### TOTP Not Working
**Symptoms:** 1Password TOTP codes not accepted by service
**Causes:**
- Time sync issue
- Wrong secret key
- Service doesn't support TOTP
- 1Password configuration error

**Solutions:**
1. Check time sync on device
2. Verify secret key in 1Password
3. Try manual entry of secret key
4. Contact service support if needed

#### SMS Required
**Symptoms:** Service only offers SMS 2FA, no TOTP option
**Causes:**
- Service doesn't support TOTP
- TOTP option hidden in settings
- Service requires phone verification

**Solutions:**
1. Look for TOTP option in security settings
2. Contact service support to enable TOTP
3. Use Hushed number for SMS
4. Consider if service is worth SMS cost

### Phone Issues

#### Hushed Not Receiving SMS
**Symptoms:** SMS codes not arriving at Hushed number
**Causes:**
- Hushed number expired
- Service blocking virtual numbers
- Network connectivity issue
- Hushed service problem

**Solutions:**
1. Check Hushed account status
2. Verify number is active
3. Try different Hushed number
4. Contact Hushed support

#### Service Rejecting Hushed Number
**Symptoms:** Service won't accept Hushed number for verification
**Causes:**
- Service blocks virtual numbers
- Number format issue
- Service requires real phone

**Solutions:**
1. Try different Hushed number
2. Use Google Voice instead
3. Consider if service is worth real phone
4. Look for alternative verification methods

### Payment Issues

#### Privacy.com Card Declined
**Symptoms:** Virtual card payment rejected
**Causes:**
- Insufficient funds
- Card spending limit reached
- Service blocks virtual cards
- Billing address mismatch

**Solutions:**
1. Check Privacy.com balance
2. Increase spending limit
3. Try different card
4. Use real billing address if required

#### Service Requires Real Payment
**Symptoms:** Service won't accept Privacy.com card
**Causes:**
- Service blocks virtual cards
- Requires real credit card
- Compliance requirements

**Solutions:**
1. Try different Privacy.com card
2. Use real credit card if necessary
3. Consider if service is worth real payment
4. Look for alternative payment methods

### Service Migration Issues

#### Can't Change Email
**Symptoms:** Service won't let you update email address
**Causes:**
- Account locked
- Email already in use
- Service restriction
- Technical issue

**Solutions:**
1. Contact service support
2. Try different email address
3. Create new account
4. Wait and try again later

#### OAuth Sign-in Only
**Symptoms:** Service only offers Google/Facebook sign-in
**Causes:**
- Service doesn't support email/password
- OAuth required for security
- Service design choice

**Solutions:**
1. Look for email/password option
2. Create new account with softmoth email
3. Use OAuth but minimize data sharing
4. Consider if service is worth OAuth

### 1Password Issues

#### TOTP Not Syncing
**Symptoms:** TOTP codes not appearing on all devices
**Causes:**
- Sync issue
- Account not signed in
- Device not connected
- 1Password service problem

**Solutions:**
1. Check 1Password sync status
2. Sign out and back in
3. Restart 1Password
4. Contact 1Password support

#### Vault Not Opening
**Symptoms:** Can't access 1Password vault
**Causes:**
- Wrong master password
- Account locked
- Device not authorized
- 1Password service down

**Solutions:**
1. Verify master password
2. Check account status
3. Authorize device
4. Contact 1Password support

## Emergency Procedures

### Compromised Email
1. **Immediately block** the compromised address in Fastmail
2. **Create new address** for that service
3. **Update service** with new email
4. **Document change** in 1Password
5. **Monitor for** other compromises

### Compromised Phone
1. **Let Hushed number expire** if possible
2. **Get new Hushed number** if needed
3. **Update services** with new number
4. **Document change** in 1Password
5. **Monitor for** other compromises

### Compromised Payment
1. **Cancel Privacy.com card** immediately
2. **Create new card** for that service
3. **Update service** with new card
4. **Document change** in 1Password
5. **Monitor for** other compromises

### Compromised 1Password
1. **Change master password** immediately
2. **Sign out all devices**
3. **Sign back in** on trusted devices
4. **Review vault** for other compromises
5. **Contact 1Password support**

## Prevention

### Regular Maintenance
- **Weekly:** Review new accounts
- **Monthly:** Check for compromises
- **Quarterly:** Update passwords
- **Annually:** Review entire system

### Security Best Practices
- **Use unique passwords** for everything
- **Enable 2FA** wherever possible
- **Monitor accounts** regularly
- **Update software** promptly

### Documentation
- **Document everything** in 1Password
- **Keep backups** of important data
- **Review procedures** regularly
- **Update documentation** as needed

## Getting Help

### Self-Help
1. **Check this guide** first
2. **Search 1Password** for similar issues
3. **Check service documentation**
4. **Try different approaches**

### Service Support
1. **Contact service support** directly
2. **Provide specific details** about the issue
3. **Be patient** with response times
4. **Escalate if needed**

### Community Help
1. **Search online** for similar issues
2. **Ask in privacy communities**
3. **Share solutions** with others
4. **Learn from others' experiences**

## Contact Information

### Service Support
- **Fastmail:** support@fastmail.com
- **Hushed:** support@hushed.com
- **Privacy.com:** support@privacy.com
- **1Password:** support@1password.com

### Emergency Contacts
- **Identity theft:** Federal Trade Commission
- **Harassment:** Local law enforcement
- **Data breaches:** Service providers
- **Legal issues:** Attorney consultation

## Diagnostic Tools

### Email Testing
- **Send test email** to alias
- **Check spam folder** in Fastmail
- **Verify forwarding** works
- **Test reply** functionality

### 2FA Testing
- **Generate TOTP code** in 1Password
- **Test with service** immediately
- **Check time sync** on device
- **Verify secret key** is correct

### Phone Testing
- **Send test SMS** to Hushed number
- **Check Hushed app** for messages
- **Verify number** is active
- **Test with service** if needed

### Payment Testing
- **Create test card** in Privacy.com
- **Make small purchase** to test
- **Verify transaction** appears
- **Check spending limits** are correct

## Common Error Messages

### Email Errors
- **"Email not found"** - Check spelling, verify alias exists
- **"Delivery failed"** - Check spam folder, verify forwarding
- **"Invalid email"** - Check format, verify domain

### 2FA Errors
- **"Invalid code"** - Check time sync, verify secret key
- **"Code expired"** - Generate new code, try again
- **"Too many attempts"** - Wait and try again later

### Phone Errors
- **"Invalid number"** - Check format, verify number is active
- **"Number not supported"** - Try different number, contact support
- **"SMS failed"** - Check network, verify number

### Payment Errors
- **"Card declined"** - Check balance, verify limits
- **"Invalid card"** - Check details, try different card
- **"Payment failed"** - Check service, verify card

## Recovery Procedures

### Account Recovery
1. **Identify the issue** - What's not working?
2. **Check documentation** - What should it be?
3. **Try basic fixes** - Restart, re-login, etc.
4. **Contact support** - If basic fixes don't work
5. **Document solution** - For future reference

### Data Recovery
1. **Check backups** - 1Password, Fastmail, etc.
2. **Restore from backup** - If available
3. **Recreate manually** - If no backup
4. **Update documentation** - With new information
5. **Test everything** - Verify it works

### Service Recovery
1. **Identify affected services** - Which ones are broken?
2. **Check service status** - Are they down?
3. **Try alternative methods** - Different login, etc.
4. **Contact service support** - If needed
5. **Update procedures** - Based on what you learn

## Maintenance Procedures

### Daily Maintenance
- **Check email** for new messages
- **Review 1Password** for updates
- **Monitor Privacy.com** for transactions
- **Check for** any security alerts

### Weekly Maintenance
- **Audit new accounts** - What did you sign up for?
- **Check for leaks** - Any identity exposure?
- **Review spending** - Privacy.com usage
- **Update documentation** - New services, changes

### Monthly Maintenance
- **Full security audit** - Review everything
- **Check for compromises** - Any suspicious activity?
- **Optimize costs** - Cancel unused services
- **Update procedures** - Based on experience

### Quarterly Maintenance
- **Review entire system** - What's working? What's not?
- **Update passwords** - Change important ones
- **Check service terms** - Any changes?
- **Plan improvements** - What can be better?

---

*This troubleshooting guide covers the most common issues you might encounter with your privacy architecture. Keep it updated as you discover new issues and solutions.*
