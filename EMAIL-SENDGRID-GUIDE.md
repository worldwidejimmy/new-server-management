# SendGrid Email Setup Guide for kludgebot.com

## Overview
This guide walks through setting up SendGrid to send authenticated emails from `johnny@kludgebot.com` through Gmail, solving the "unverified sender" problem.

## Why SendGrid?

**Problem:** Regular Gmail accounts cannot properly authenticate custom domain emails with DKIM, resulting in "unverified sender" warnings.

**Solution:** SendGrid provides free SMTP relay with proper DKIM/SPF authentication.

**Benefits:**
- ✅ Free tier: 100 emails/day forever
- ✅ Proper DKIM signing
- ✅ No "unverified sender" warnings
- ✅ Better deliverability to Gmail/other providers
- ✅ Works with Gmail's "Send mail as" feature

## Port 25 Block Issue

Our OVH VPS has outbound SMTP ports blocked:
- Port 25: BLOCKED ❌
- Port 465: BLOCKED ❌
- Port 587: BLOCKED ❌

This means we cannot run our own Postfix server to send emails directly. SendGrid solves this by providing an external relay service.

---

## Setup Steps

### 1. Create SendGrid Account

1. Go to: https://signup.sendgrid.com/
2. Sign up for free account (no credit card required)
3. Verify your email address

**Important:** The "trial" messaging is misleading - the free tier (100 emails/day) is permanent. Just don't add a credit card.

### 2. Domain Authentication

In SendGrid dashboard:
1. Go to **Settings** → **Sender Authentication** → **Authenticate Your Domain**
2. Select "Other Host" (we use Cloudflare)
3. Enter domain: `kludgebot.com`
4. Enable **Link Branding** (free, makes links show your domain)

### 3. Add DNS Records to Cloudflare

SendGrid will provide DNS records. Add these to Cloudflare DNS:

**CRITICAL: All records must be GRAY CLOUD (DNS only), not orange proxy!**

#### CNAME Records (already added):
```
Type    Name                          Value
CNAME   56740961.kludgebot.com       sendgrid.net
CNAME   em5571.kludgebot.com         u56740961.wl212.sendgrid.net
CNAME   s1._domainkey.kludgebot.com  s1.domainkey.u56740961.wl212.sendgrid.net
CNAME   s2._domainkey.kludgebot.com  s2.domainkey.u56740961.wl212.sendgrid.net
CNAME   url6963.kludgebot.com        sendgrid.net
```

#### Update SPF Record:

**Current SPF:**
```
v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all
```

**Updated SPF (add SendGrid):**
```
v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com include:sendgrid.net ~all
```

**To update in Cloudflare:**
1. Go to DNS records for kludgebot.com
2. Find TXT record with `v=spf1`
3. Edit and add `include:sendgrid.net` before `~all`
4. Save

#### DMARC Record:
Already exists from Cloudflare Email Routing setup:
```
_dmarc.kludgebot.com → "v=DMARC1; p=none; rua=mailto:d0073d3c6661414fa6f7388426e0bafc@dmarc-reports.cloudflare.net"
```

### 4. Verify in SendGrid

1. Wait 2-5 minutes for DNS propagation
2. In SendGrid, click **"Verify"** on the domain authentication page
3. All records should turn green ✅

### 5. Create API Key for SMTP

1. In SendGrid: **Settings** → **API Keys**
2. Click **"Create API Key"**
3. Name it: `Gmail SMTP` or similar
4. Permissions: **Full Access** (or at minimum "Mail Send")
5. Copy the API key (you'll only see it once!)

### 6. Add to Gmail

In Gmail Settings:
1. Click gear icon → **See all settings**
2. Go to **Accounts and Import** tab
3. In "Send mail as" section, find `johnny@kludgebot.com`
4. Click **"edit info"**
5. Update SMTP settings:
   - **SMTP Server:** `smtp.sendgrid.net`
   - **Port:** `587`
   - **Username:** `apikey` (literally the word "apikey")
   - **Password:** (paste your SendGrid API key)
   - **Secured connection:** TLS
6. Save changes

If you don't have the "Send mail as" set up yet:
1. Click **"Add another email address"**
2. Enter: `johnny@kludgebot.com`
3. Use the SMTP settings above
4. Verify the email address

### 7. Test It!

1. In Gmail, compose a new email
2. Click the "From" dropdown
3. Select `johnny@kludgebot.com`
4. Send a test email to yourself
5. Check the email headers - should show:
   - ✅ DKIM: PASS
   - ✅ SPF: PASS
   - ✅ No "unverified sender" warning

---

## Current DNS Configuration

See full DNS export in `kludgebot.com.txt` or `kludgebot.com (1).txt`

**Key records:**
- SPF: Includes Cloudflare, Google, and SendGrid
- DKIM: Cloudflare (`cf2024-1._domainkey`) + SendGrid (`s1`, `s2._domainkey`)
- DMARC: Cloudflare Email Routing reports
- MX: Cloudflare Email Routing

---

## Troubleshooting

### "Unverified sender" still shows
- Check SPF includes `sendgrid.net`
- Verify all SendGrid DNS records are added correctly
- Wait 24 hours for DNS propagation
- Make sure records are GRAY CLOUD in Cloudflare

### Emails not sending
- Verify API key is correct
- Check you haven't exceeded 100 emails/day
- Verify domain authentication is complete in SendGrid
- Check SendGrid Activity feed for errors

### Gmail won't accept SMTP settings
- Username must be exactly `apikey` (not your email)
- Password is the API key from SendGrid
- Port must be 587 with TLS
- Make sure you generated an API key with Mail Send permissions

### SendGrid verification fails
- Ensure CNAME records are DNS only (gray cloud)
- Wait 5-10 minutes after adding DNS records
- Check for typos in DNS record names/values
- Verify no duplicate records exist

---

## Free Tier Limits

**SendGrid Free Plan:**
- 100 emails per day (forever)
- No credit card required
- Full SMTP access
- Domain authentication included
- Link branding included

**After "trial" ends (Dec 14, 2025):**
- Automatically becomes permanent free plan
- Same 100 emails/day limit
- No charges as long as no credit card on file
- Ignore "invoice" messaging - it's just standard wording

---

## Alternative Options Considered

### 1. Keep using Gmail SMTP
- ❌ "Unverified sender" warning persists
- ❌ Lower deliverability
- ✅ Easy, no changes

### 2. Run own Postfix server on VPS
- ❌ OVH blocks all outbound SMTP ports
- ❌ Would need to request unblocking (takes time, may be denied)
- ✅ Full control if ports were unblocked

### 3. Google Workspace
- ✅ Proper DKIM signing
- ✅ Professional features
- ❌ $6-18/month cost

### 4. Cloudflare Email Routing
- ❌ Receive-only, no outbound SMTP
- ✅ Good for forwarding incoming mail

**SendGrid was chosen as the best balance of cost (free), functionality, and ease of setup.**

---

## Node.js Integration (Future)

To send emails from Node.js apps using SendGrid:

```javascript
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

const msg = {
  to: 'recipient@example.com',
  from: 'johnny@kludgebot.com',
  subject: 'Hello from Node.js',
  text: 'Email body',
  html: '<strong>Email body</strong>',
};

sgMail.send(msg);
```

Or use Nodemailer with SendGrid SMTP:

```javascript
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: 'smtp.sendgrid.net',
  port: 587,
  auth: {
    user: 'apikey',
    pass: process.env.SENDGRID_API_KEY
  }
});

transporter.sendMail({
  from: 'johnny@kludgebot.com',
  to: 'recipient@example.com',
  subject: 'Hello from Node.js',
  text: 'Email body'
});
```

---

## Server Information

- **VPS:** vps-9108f4ba.vps.ovh.us
- **IP:** 40.160.237.83
- **Provider:** OVH Cloud
- **OS:** Ubuntu
- **Web Root:** /var/www/talkingyam.com

---

## Related Documentation

- Full DNS export: `kludgebot.com.txt`, `kludgebot.com (1).txt`
- Email DNS setup (legacy): `EMAIL-DNS-SETUP-GUIDE.md`

---

## Status: ✅ ACTIVE

- SendGrid account created: ✅
- Domain authenticated: ✅
- DNS records added: ✅
- SPF updated: ✅
- Link branding enabled: ✅
- Gmail SMTP configured: ⏳ (pending API key setup)

Last updated: October 15, 2025

---

## ✅ SETUP COMPLETE - October 15, 2025

### Final Status:
- ✅ SendGrid account created
- ✅ Domain authenticated and verified (`em5571.kludgebot.com`)
- ✅ All DNS records added to Cloudflare (CNAME for DKIM, link branding)
- ✅ SPF record updated with `include:sendgrid.net`
- ✅ Link branding enabled
- ✅ SendGrid domain verification: **VERIFIED** (green checkmark)

### Remaining Steps:
1. Create API key in SendGrid (Settings → API Keys → Create API Key)
2. Configure Gmail SMTP with SendGrid credentials:
   - SMTP Server: `smtp.sendgrid.net`
   - Port: `587`
   - Username: `apikey`
   - Password: (SendGrid API key)
   - TLS: Yes
3. Test email sending from Gmail
4. Verify no "unverified sender" warning appears

### Notes:
- Domain verification completed successfully - no additional authentication needed
- The verified subdomain `em5571.kludgebot.com` is used by SendGrid for technical routing
- Emails will still display as from `johnny@kludgebot.com` to recipients
- Free tier limit: 100 emails/day

---

## 🎉 FULLY OPERATIONAL - October 15, 2025

### All Steps Completed:
- ✅ SendGrid account created
- ✅ Domain authenticated and verified
- ✅ All DNS records configured in Cloudflare
- ✅ SPF record updated with SendGrid
- ✅ API key created and configured
- ✅ Gmail SMTP configured with SendGrid
- ✅ **TESTED AND WORKING** - Emails sending successfully!

**Status:** Production-ready. No "unverified sender" warnings. Proper email authentication in place.

**Free tier usage:** 100 emails/day available.

Setup completed and tested: October 15, 2025
