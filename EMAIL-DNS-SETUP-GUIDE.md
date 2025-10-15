# Email, DNS & SSL Setup Guide for kludgebot.bot

> **⚠️ IMPORTANT: For sending authenticated emails from johnny@kludgebot.com through Gmail, see [EMAIL-SENDGRID-GUIDE.md](./EMAIL-SENDGRID-GUIDE.md) first!**
>
> This guide covers the legacy/original setup for kludgebot.bot domain. For the current kludgebot.com SendGrid implementation (recommended), use the SendGrid guide.

**Cloudflare + OVH + Gmail Integration**

---

## 🎯 Goals

1. ✅ **Receive emails:** Forward all `*@kludgebot.bot` to your Gmail
2. ✅ **Send emails:** Send from `johnny@kludgebot.bot` via Gmail (authenticated)
3. ✅ **DNS:** Proper A records for website
4. ✅ **SSL:** Let's Encrypt certificates
5. ✅ **Email security:** SPF, DKIM, DMARC to prevent spam

---

## 📧 Email Strategy: Cloudflare Email Routing

**Why Cloudflare Email Routing?**
- ✅ **Free** and unlimited
- ✅ **Wildcard forwarding** built-in
- ✅ **No mail server needed** on OVH
- ✅ **Spam filtering** included
- ✅ **Easy setup** - just DNS records
- ✅ **Reliable** - Cloudflare's infrastructure

**Alternative Rejected:** Running your own mail server (Postfix/Dovecot) is complex, requires constant maintenance, easily ends up in spam folders.

---

## 🔧 Step-by-Step Setup

### Step 1: Transfer Domain to Cloudflare

If domain is currently registered with IONOS:

1. Log into IONOS account
2. Unlock domain `kludgebot.bot`
3. Get authorization code (EPP code)
4. Go to Cloudflare → Add Site → Transfer Domain
5. Enter authorization code
6. Pay transfer fee (typically $8-15/year, includes 1-year renewal)
7. Wait for transfer (can take 5-7 days)

**OR** if already transferred:
- Domain is registered with Cloudflare
- Move to Step 2

---

### Step 2: Cloudflare DNS Setup

Go to Cloudflare Dashboard → Your domain → DNS → Records

#### A Records (Website)

```
Type: A
Name: @
Content: YOUR_OVH_SERVER_IP
Proxy: OFF (gray cloud) ← Important for initial SSL setup
TTL: Auto

Type: A
Name: www
Content: YOUR_OVH_SERVER_IP
Proxy: OFF (gray cloud)
TTL: Auto
```

**Note:** Turn proxy ON (orange cloud) AFTER SSL certificate is installed

#### MX Records (Email Receiving)

Cloudflare Email Routing uses these:

```
Type: MX
Name: @
Priority: 1
Content: route1.mx.cloudflare.net
TTL: Auto

Type: MX
Name: @
Priority: 2
Content: route2.mx.cloudflare.net
TTL: Auto

Type: MX
Name: @
Priority: 3
Content: route3.mx.cloudflare.net
TTL: Auto
```

**Note:** Cloudflare may auto-create these when you enable Email Routing

#### SPF Record (Email Security)

```
Type: TXT
Name: @
Content: v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all
TTL: Auto
```

**Explanation:**
- `include:_spf.mx.cloudflare.net` - Allow Cloudflare to send (for forwarding)
- `include:_spf.google.com` - Allow Gmail to send from your domain
- `~all` - Soft fail for others (mark as suspicious but don't reject)

#### DMARC Record (Email Policy)

```
Type: TXT
Name: _dmarc
Content: v=DMARC1; p=quarantine; rua=mailto:johnny@kludgebot.bot; ruf=mailto:johnny@kludgebot.bot; pct=100
TTL: Auto
```

**Explanation:**
- `p=quarantine` - Suspicious emails go to spam (use `p=none` initially for testing)
- `rua=` - Aggregate reports sent here
- `ruf=` - Forensic reports sent here
- `pct=100` - Apply policy to 100% of emails

---

### Step 3: Enable Cloudflare Email Routing

1. Go to Cloudflare Dashboard → Email → Email Routing
2. Click **Get Started**
3. Cloudflare will:
   - Auto-create MX records
   - Add necessary TXT records
   - Verify DNS configuration

4. **Add Destination:**
   - Click "Destination addresses"
   - Add your Gmail: `youremail@gmail.com`
   - Verify (check Gmail for verification email)

5. **Create Routing Rules:**

   **Option A: Catch-all (wildcard)**
   ```
   Type: Catch-all
   Action: Send to youremail@gmail.com
   ```
   This forwards EVERYTHING to Gmail

   **Option B: Specific addresses**
   ```
   johnny@kludgebot.bot → youremail@gmail.com
   support@kludgebot.bot → youremail@gmail.com
   admin@kludgebot.bot → youremail@gmail.com
   (plus catch-all for everything else)
   ```

6. **Enable** Email Routing

**Test receiving:**
- Send email to `test@kludgebot.bot` from another account
- Should arrive in Gmail within seconds
- Check spam folder if not in inbox

---

### Step 4: Configure Gmail to Send as johnny@kludgebot.bot

#### Method A: Gmail "Send mail as" (Recommended - Easier)

1. **In Gmail:**
   - Settings (gear icon) → See all settings
   - Go to **Accounts and Import** tab
   - Under "Send mail as" → Click **Add another email address**

2. **Add Email Address:**
   ```
   Name: Johnny (or your name)
   Email: johnny@kludgebot.bot
   ☐ Treat as an alias (leave UNCHECKED for better deliverability)
   ```
   Click **Next Step**

3. **SMTP Settings:**
   ```
   SMTP Server: smtp.gmail.com
   Port: 587
   Username: youremail@gmail.com (your actual Gmail address)
   Password: (App Password - see below)
   ☑ Secured connection using TLS
   ```

4. **Create App Password:**
   - Go to Google Account → Security
   - 2-Step Verification must be ON
   - Scroll to "App passwords"
   - Create new app password for "Mail"
   - Copy 16-character password
   - Paste into Gmail SMTP password field

5. **Verify:**
   - Gmail sends verification email to `johnny@kludgebot.bot`
   - Check your Gmail (Cloudflare forwards it)
   - Click verification link

6. **Set as Default (Optional):**
   - Back in Gmail Settings → Accounts
   - Make `johnny@kludgebot.bot` the default "Send mail as"

**Test sending:**
- Compose new email in Gmail
- From dropdown should show `johnny@kludgebot.bot`
- Send to another email address
- Check headers - should show "via gmail.com" but from address is your domain

---

#### Method B: Custom SMTP Server (Advanced - Better Deliverability)

If you want to remove "via gmail.com" from headers, you need your own SMTP:

**Option 1: Use Cloudflare's SMTP (if available)**
- Check if Cloudflare offers SMTP sending
- As of 2025, this may be in beta

**Option 2: Use third-party SMTP service**
- SendGrid (100 emails/day free)
- Mailgun (100 emails/day free)
- Amazon SES ($0.10 per 1000 emails)

**Option 3: Run your own (NOT recommended)**
- Install Postfix on OVH server
- Configure DKIM signing
- High risk of being marked as spam
- Requires constant maintenance

**For most use cases, Method A (Gmail SMTP) is perfect!**

---

### Step 5: DKIM Setup (Optional but Recommended)

DKIM (DomainKeys Identified Mail) adds a digital signature to your emails.

#### For Gmail Sending:

Gmail automatically signs with Google's DKIM when using their SMTP. No action needed!

#### For Cloudflare Forwarding:

Cloudflare may strip original DKIM signatures. To improve deliverability:

1. In Cloudflare Email Routing settings
2. Check if DKIM signing is available
3. If yes, enable it and add the provided DNS record

**Example DKIM record (format varies):**
```
Type: TXT
Name: cloudflare._domainkey
Content: v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBA...
TTL: Auto
```

---

### Step 6: Test Your Setup

#### Test Email Receiving:
```bash
# Send test email from another account to:
test@kludgebot.bot
johnny@kludgebot.bot
randomstring@kludgebot.bot

# All should arrive in Gmail
```

#### Test Email Sending:
```bash
# From Gmail, send as johnny@kludgebot.bot to:
# - Another Gmail account
# - Outlook/Hotmail
# - Yahoo

# Check:
# - Email arrives (not in spam)
# - "From" shows johnny@kludgebot.bot
# - May show "via gmail.com" (this is normal and trusted)
```

#### Test SPF/DKIM/DMARC:

Send test email to: `check-auth@verifier.port25.com`

You'll receive automated report showing:
- ✅ SPF: PASS
- ✅ DKIM: PASS
- ✅ DMARC: PASS

**Or use online tools:**
- https://mxtoolbox.com/domain/kludgebot.bot
- https://www.mail-tester.com/

---

## 📋 Complete DNS Configuration Checklist

After setup, your Cloudflare DNS should have:

```
A       @       YOUR_OVH_IP             (Proxy: OFF initially)
A       www     YOUR_OVH_IP             (Proxy: OFF initially)
MX      @       1  route1.mx.cloudflare.net
MX      @       2  route2.mx.cloudflare.net
MX      @       3  route3.mx.cloudflare.net
TXT     @       "v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all"
TXT     _dmarc  "v=DMARC1; p=quarantine; rua=mailto:johnny@kludgebot.bot"
```

Plus any Cloudflare auto-generated records for email verification.

---

## 🔒 SSL Certificate Setup (After DNS)

Once DNS is pointing to OVH server:

```bash
# On OVH server
sudo certbot --apache -d kludgebot.bot -d www.kludgebot.bot --redirect
```

Certbot will:
1. Verify domain ownership via HTTP challenge
2. Install certificate
3. Configure Apache for HTTPS
4. Set up auto-renewal

**After SSL works:**
- Go back to Cloudflare DNS
- Enable proxy (orange cloud) on A records
- This adds CDN + DDoS protection

---

## 🎯 Gmail Filters (Bonus Tip)

Since all `*@kludgebot.bot` emails forward to your Gmail, create filters:

1. **Filter for specific addresses:**
   ```
   To: johnny@kludgebot.bot
   Apply label: "Johnny (kludgebot)"
   Never send to Spam
   ```

2. **Filter for catch-all:**
   ```
   To: (*@kludgebot.bot)
   Apply label: "kludgebot-catchall"
   ```

3. **Filter for automated emails:**
   ```
   To: noreply@kludgebot.bot OR admin@kludgebot.bot
   Apply label: "kludgebot-automated"
   Skip inbox (archive)
   ```

---

## 🚨 Troubleshooting

### Emails Not Arriving in Gmail

1. **Check Cloudflare Email Routing:**
   - Is it enabled?
   - Is destination verified?
   - Are routing rules active?

2. **Check MX records:**
   ```bash
   dig MX kludgebot.bot
   # Should show Cloudflare's MX servers
   ```

3. **Check Gmail spam folder**

4. **Check Cloudflare logs:**
   - Email → Email Routing → Activity log

### Can't Send from Gmail

1. **App Password issues:**
   - 2FA must be enabled on Google account
   - Generate new app password
   - Use app password, not your regular password

2. **SMTP settings wrong:**
   - Server: `smtp.gmail.com`
   - Port: `587` (not 465 or 25)
   - TLS enabled

3. **Verification not completed:**
   - Check Gmail for verification email
   - It forwards to your Gmail via Cloudflare

### Emails Going to Spam

1. **SPF not set up correctly:**
   ```bash
   dig TXT kludgebot.bot
   # Should show SPF record
   ```

2. **No DMARC policy:**
   ```bash
   dig TXT _dmarc.kludgebot.bot
   # Should show DMARC record
   ```

3. **Gmail "via" warning:**
   - This is normal when using Gmail SMTP
   - Not marked as spam by most providers
   - To remove, need custom SMTP (complex)

4. **Sending too many emails:**
   - Gmail has daily limits
   - ~500 emails/day for regular accounts
   - ~2000/day for Google Workspace

---

## 💡 Best Practices

### Email Security
- ✅ Always use SPF, DKIM, DMARC
- ✅ Use catch-all for convenience
- ✅ Create specific addresses for important functions
- ✅ Monitor DMARC reports to catch spoofing attempts

### Domain Management
- ✅ Keep domain registration with Cloudflare (easier management)
- ✅ Use Cloudflare proxy after SSL is working (performance + security)
- ✅ Set up email forwarding BEFORE migrating away from old provider
- ✅ Test thoroughly before announcing new email

### Gmail Integration
- ✅ Use App Passwords (never your main password)
- ✅ Set up filters to organize forwarded emails
- ✅ Consider multiple addresses (johnny@, support@, admin@)
- ✅ Don't abuse - Gmail has sending limits

---

## 📚 Additional Email Addresses

Once basic setup works, easily add more:

### In Cloudflare Email Routing:

```
johnny@kludgebot.bot → youremail@gmail.com
support@kludgebot.bot → youremail@gmail.com
admin@kludgebot.bot → youremail@gmail.com
bot@kludgebot.bot → youremail@gmail.com
noreply@kludgebot.bot → youremail@gmail.com (or drop)
```

### In Gmail "Send mail as":

Add each address you want to send from:
- `johnny@kludgebot.bot` (primary)
- `support@kludgebot.bot` (customer support)
- `admin@kludgebot.bot` (technical)

All use the same Gmail SMTP settings!

---

## 🎉 Expected Results

After complete setup:

✅ **Receiving:**
- All emails to `*@kludgebot.bot` appear in Gmail inbox
- Properly labeled/filtered
- No spam issues

✅ **Sending:**
- Can send from `johnny@kludgebot.bot` in Gmail
- Recipients see your custom domain
- Not marked as spam
- Professional appearance

✅ **Security:**
- SPF, DKIM, DMARC all passing
- Protected from spoofing
- Trusted by major email providers

✅ **Convenience:**
- No mail server to maintain
- All managed in Gmail interface
- Mobile apps work perfectly
- Unlimited storage (Gmail)

---

**Ready to start? Let me know which step you want to tackle first!** 🚀

**Recommended order:**
1. Transfer domain to Cloudflare (if not done)
2. Set up basic DNS (A records)
3. Enable Cloudflare Email Routing
4. Configure Gmail sending
5. Install SSL on OVH server
6. Test everything!
