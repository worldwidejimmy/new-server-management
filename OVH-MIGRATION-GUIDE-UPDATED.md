# OVH Migration Guide - Based on Actual IONOS Setup

**Migration Date:** October 14, 2025  
**From:** IONOS Ubuntu 20.04.6 LTS (root user)  
**To:** OVH Ubuntu 24.04.3 LTS (ubuntu user)  

---

## 📊 Current IONOS Server Inventory

### Existing Domains & SSL Certificates
All domains currently have valid SSL certificates:

| Domain | Expires | Status |
|--------|---------|--------|
| carboncruiser.com | Jan 10, 2026 | Valid (88 days) |
| fatjimmy.com | Jan 10, 2026 | Valid (88 days) |
| johnhorvath.com | Jan 10, 2026 | Valid (88 days) |
| nanoassassin.com | Nov 21, 2025 | Valid (37 days) |
| presidentclownshow.com | Nov 13, 2025 | Valid (29 days) |
| talkingyam.com | Jan 10, 2026 | Valid (88 days) |

**Note:** kludgebot.bot is NEW - not on IONOS, going straight to OVH

### Current Apps Running on IONOS

Located in `/opt/apps/`:

| App | Dev Port | Prod Port | PM2 Status | Domain |
|-----|----------|-----------|------------|---------|
| nanoassassin | 5001 | 5000 | online | nanoassassin.com |
| blurbrank | 5011 | 5010 | online | presidentclownshow.com |
| fatjimmy-dashboard | 5020 | - | online (dev) | fatjimmy.com |
| beatbox | 5030 | - | stopped | - |
| snakegame | 5040 | - | stopped | - |
| trycodex | 5050 | - | - | - |
| epicages | 5060 | - | - | - |
| tonescope | - | - | - | - (frontend-only) |
| trygrokcode | - | - | - | - (frontend-only) |

**Next available port:** 5070 (perfect for kludgebot!)

### Software Versions (IONOS)
- **Node.js:** v18.20.8
- **npm:** 10.8.2
- **PM2:** 6.0.13
- **Apache:** 2.4.41
- **Ubuntu:** 20.04.6 LTS

### Key Files Found
- ✅ `/opt/apps/app-registry.json` - Port management database
- ✅ `/opt/apps/get-port.sh` - Helper script
- ✅ `/opt/apps/pm2-experimental.config.js` - PM2 ecosystem config
- ✅ Working Apache SSL configs for all domains

---

## 🎯 Migration Strategy

### Phase 1: Setup OVH Server (New Domain)
**Target:** kludgebot.bot (brand new domain)
- Install matching software stack
- Use port 5070 (next available)
- Transfer domain from IONOS to Cloudflare
- Set up on OVH before touching production apps

### Phase 2: Migrate Production Apps (One by One)
**Order suggestion:**
1. nanoassassin.com (port 5000 → keep 5000)
2. presidentclownshow.com/blurbrank (port 5010 → keep 5010)
3. fatjimmy.com/dashboard (port 5020 → keep 5020)
4. Other domains as needed

### Phase 3: Development Apps
- Clone dev environments as needed
- No rush on these

---

## 🛠️ OVH Server Setup - Step by Step

### Directory Structure Decision

**IONOS uses:** `/opt/apps/` (owned by root)  
**OVH options:**
1. **Use `/home/ubuntu/apps/`** (recommended - cleaner permissions)
2. **Use `/opt/apps/`** (matches IONOS, requires sudo setup)

**Recommendation:** Use `/home/ubuntu/apps/` for cleaner workflow

```bash
mkdir -p ~/apps
mkdir -p ~/server-management
mkdir -p ~/backups
```

### Software Installation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20.x (newer than IONOS 18.x, but compatible)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify versions
node --version  # Should be v20.x.x
npm --version

# Install PM2 globally
sudo npm install -g pm2

# Set up PM2 to start on boot
pm2 startup
# Run the command it outputs (sudo env PATH=$PATH...)
pm2 save

# Install Apache
sudo apt install -y apache2

# Enable required Apache modules
sudo a2enmod proxy proxy_http rewrite ssl headers

# Install Certbot
sudo apt install -y certbot python3-certbot-apache

# Configure firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status
```

### Copy Existing Config Files

Copy these from IONOS to OVH:

```bash
# On IONOS, create a bundle
cd /opt/apps
tar -czf ~/ionos-configs.tar.gz \
  app-registry.json \
  get-port.sh \
  pm2-experimental.config.js

# Transfer to OVH (use scp or copy content manually)
# Then on OVH:
cd ~/apps
tar -xzf ~/ionos-configs.tar.gz

# Make get-port.sh executable
chmod +x ~/apps/get-port.sh
```

Or manually recreate them (I can help with this)

---

## 🚀 Deploy First App: kludgebot.bot

### Step 1: Setup App Registry

Create `~/apps/app-registry.json`:

```json
{
  "apps": {
    "kludgebot": {
      "name": "Kludgebot",
      "dev": {
        "port": 5071,
        "path": "/home/ubuntu/apps/kludgebot.dev",
        "autostart": false
      },
      "prod": {
        "port": 5070,
        "path": "/home/ubuntu/apps/kludgebot.prod",
        "autostart": true,
        "domain": "kludgebot.bot"
      }
    }
  },
  "portAllocation": {
    "strategy": "Block of 10 per app (X000-X009)",
    "nextAvailable": 5080,
    "reserved": {
      "5000-5009": "nanoassassin (future migration)",
      "5010-5019": "blurbrank (future migration)",
      "5020-5029": "fatjimmy-dashboard (future migration)",
      "5030-5039": "beatbox (future migration)",
      "5040-5049": "snakegame (future migration)",
      "5050-5059": "trycodex (future migration)",
      "5060-5069": "epicages (future migration)",
      "5070-5079": "kludgebot"
    }
  }
}
```

### Step 2: Clone or Create Kludgebot

```bash
cd ~/apps

# Option A: Clone existing repo
git clone git@github.com:yourusername/kludgebot.git kludgebot.dev
git clone git@github.com:yourusername/kludgebot.git kludgebot.prod

# Option B: Create new React+Express app
# (see original migration guide for full setup)

# Install dependencies
cd ~/apps/kludgebot.prod
npm install

# Create .env
echo "PORT=5070" > .env
echo "NODE_ENV=production" >> .env

# Build
npm run build
```

### Step 3: Apache Configuration

```bash
# Create HTTP config first
sudo nano /etc/apache2/sites-available/kludgebot.bot.conf
```

**Basic HTTP config:**
```apache
<VirtualHost *:80>
    ServerName kludgebot.bot
    ServerAlias www.kludgebot.bot
    DocumentRoot /var/www/kludgebot.bot

    <Directory /var/www/kludgebot.bot>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/kludgebot.bot_error.log
    CustomLog ${APACHE_LOG_DIR}/kludgebot.bot_access.log combined
</VirtualHost>
```

```bash
# Create web directory
sudo mkdir -p /var/www/kludgebot.bot
sudo chown -R ubuntu:ubuntu /var/www/kludgebot.bot

# Enable site
sudo a2ensite kludgebot.bot.conf
sudo apache2ctl configtest
sudo systemctl reload apache2

# Deploy frontend
cp -r ~/apps/kludgebot.prod/dist/public/* /var/www/kludgebot.bot/
```

### Step 4: Cloudflare DNS Setup

**CRITICAL:** Proxy must be OFF initially for SSL to work!

1. Log into Cloudflare
2. Add domain: kludgebot.bot
3. Create DNS records:

```
Type: A
Name: @
Content: YOUR_OVH_SERVER_IP
Proxy: OFF (gray cloud) ← IMPORTANT!

Type: A  
Name: www
Content: YOUR_OVH_SERVER_IP
Proxy: OFF (gray cloud) ← IMPORTANT!
```

4. Wait for DNS propagation (test with: `dig kludgebot.bot`)

### Step 5: Install SSL Certificate

```bash
# Request certificate
sudo certbot --apache -d kludgebot.bot -d www.kludgebot.bot --redirect

# Certbot will automatically:
# - Verify domain ownership
# - Install SSL certificate
# - Create -le-ssl.conf file
# - Set up HTTP → HTTPS redirect
```

### Step 6: Update Apache Config with Proxy

```bash
# Edit the SSL config that Certbot created
sudo nano /etc/apache2/sites-available/kludgebot.bot-le-ssl.conf
```

**Add proxy rules (based on nanoassassin.com pattern):**
```apache
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName kludgebot.bot
    ServerAlias www.kludgebot.bot
    DocumentRoot /var/www/kludgebot.bot
    
    <Directory /var/www/kludgebot.bot>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # React Router support
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
    
    # Proxy API calls to Node.js backend
    ProxyPreserveHost On
    ProxyPass /api/ http://localhost:5070/api/
    ProxyPassReverse /api/ http://localhost:5070/api/
    
    ErrorLog ${APACHE_LOG_DIR}/kludgebot.bot_error.log
    CustomLog ${APACHE_LOG_DIR}/kludgebot.bot_access.log combined
    
    Include /etc/letsencrypt/options-ssl-apache.conf
    SSLCertificateFile /etc/letsencrypt/live/kludgebot.bot/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/kludgebot.bot/privkey.pem
</VirtualHost>
</IfModule>
```

```bash
# Test and reload
sudo apache2ctl configtest
sudo systemctl reload apache2
```

### Step 7: Start Backend with PM2

```bash
cd ~/apps/kludgebot.prod

# Start with PM2
PORT=5070 pm2 start dist/index.js --name kludgebot-5070

# Save PM2 configuration
pm2 save

# Check status
pm2 status
pm2 logs kludgebot-5070
```

### Step 8: Enable Cloudflare Proxy (Optional)

Once everything works:
1. Go back to Cloudflare DNS
2. Click the gray cloud icon to enable proxy (turns orange)
3. This adds CDN + DDoS protection

---

## 📋 Migration Checklist for Each Domain

When migrating apps from IONOS to OVH:

### Pre-Migration
- [ ] Ensure app works on IONOS (test it!)
- [ ] Note current port number
- [ ] Clone repo to OVH (.dev and .prod)
- [ ] Update app-registry.json on OVH
- [ ] Build production version
- [ ] Test locally on OVH

### DNS/Domain Transfer
- [ ] Transfer domain registration from IONOS to Cloudflare
- [ ] Add domain to Cloudflare
- [ ] Create A records pointing to OVH IP
- [ ] Set Cloudflare proxy to OFF (gray cloud)
- [ ] Wait for DNS propagation (use `dig domain.com`)

### Apache & SSL
- [ ] Create Apache HTTP config on OVH
- [ ] Deploy frontend files to /var/www/
- [ ] Enable site and test HTTP access
- [ ] Install SSL with Certbot
- [ ] Update Apache config with proxy rules
- [ ] Test HTTPS access

### Backend
- [ ] Start backend with PM2 (use same port as IONOS)
- [ ] Test API endpoints
- [ ] Check PM2 logs for errors
- [ ] Save PM2 configuration

### Testing & Cutover
- [ ] Test all functionality on OVH
- [ ] Keep IONOS app running during testing
- [ ] Once confident, update Cloudflare DNS TTL to 5 minutes
- [ ] Update DNS to point to OVH (already done in earlier step)
- [ ] Monitor for 24-48 hours
- [ ] Stop IONOS version after confirming OVH is stable
- [ ] Optional: Enable Cloudflare proxy (orange cloud)

---

## 🔧 Helper Scripts

### Get Port Script (~/apps/get-port.sh)

```bash
#!/bin/bash
# Get port for an app from registry

REGISTRY_FILE="$(dirname "$0")/app-registry.json"
APP_NAME="$1"
MODE="${2:-dev}"

if [ ! -f "$REGISTRY_FILE" ]; then
    echo "ERROR: Registry file not found" >&2
    exit 1
fi

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app-name> [dev|prod]" >&2
    exit 1
fi

PORT=$(jq -r ".apps.\"$APP_NAME\".\"$MODE\".port" "$REGISTRY_FILE")

if [ "$PORT" = "null" ] || [ -z "$PORT" ]; then
    echo "ERROR: Port not found for $APP_NAME ($MODE)" >&2
    exit 1
fi

echo "$PORT"
```

**Usage:**
```bash
chmod +x ~/apps/get-port.sh
~/apps/get-port.sh kludgebot prod  # Returns: 5070
```

### Deploy Script (~/server-management/deploy.sh)

```bash
#!/bin/bash
# Deploy app to production

set -e

APP_NAME="$1"
DOMAIN="$2"

if [ -z "$APP_NAME" ] || [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <app-name> <domain>"
    echo "Example: $0 kludgebot kludgebot.bot"
    exit 1
fi

PROD_DIR="$HOME/apps/${APP_NAME}.prod"
WEB_DIR="/var/www/${DOMAIN}"
PORT=$(~/apps/get-port.sh "$APP_NAME" prod)
PM2_NAME="${APP_NAME}-${PORT}"

echo "🚀 Deploying ${APP_NAME} to ${DOMAIN}..."

cd "$PROD_DIR"
git pull origin main
npm install
npm run build

rm -rf "$WEB_DIR"/*
cp -r dist/public/* "$WEB_DIR/"

pm2 restart "$PM2_NAME"

echo "✅ Deployment complete!"
echo "🔗 Site: https://${DOMAIN}"
echo "🔍 Logs: pm2 logs ${PM2_NAME}"
```

**Usage:**
```bash
chmod +x ~/server-management/deploy.sh
~/server-management/deploy.sh kludgebot kludgebot.bot
```

---

## 🎓 Key Differences: IONOS vs OVH

| Aspect | IONOS Setup | OVH Setup |
|--------|-------------|-----------|
| **User** | root | ubuntu (with sudo) |
| **App Location** | /opt/apps/ | /home/ubuntu/apps/ |
| **Ubuntu Version** | 20.04.6 LTS | 24.04.3 LTS |
| **Node.js** | v18.20.8 | v20.x (recommended) |
| **Permissions** | Mixed root/www-data | ubuntu:ubuntu |
| **PM2 Startup** | Manual | Automated with pm2 startup |

---

## 📖 Useful Commands Reference

```bash
# PM2
pm2 list
pm2 logs appname --lines 50
pm2 restart appname
pm2 stop appname
pm2 save

# Apache
sudo apache2ctl configtest
sudo systemctl reload apache2
sudo tail -f /var/log/apache2/error.log
sudo tail -f /var/log/apache2/kludgebot.bot_error.log

# Certbot
sudo certbot certificates
sudo certbot renew --dry-run

# DNS
dig kludgebot.bot
nslookup kludgebot.bot

# Ports
sudo lsof -i :5070
sudo netstat -tlnp | grep node

# Logs
pm2 logs kludgebot-5070
pm2 logs kludgebot-5070 --lines 100
```

---

## 🆘 Troubleshooting

### SSL Certificate Fails
**Cause:** DNS not pointing to server or Cloudflare proxy is ON

**Fix:**
1. Check DNS: `dig kludgebot.bot` should show OVH IP
2. Verify Cloudflare proxy is OFF (gray cloud)
3. Test HTTP access: `curl http://kludgebot.bot`
4. Check port 80 is open: `sudo ufw status`
5. Retry: `sudo certbot --apache -d kludgebot.bot -d www.kludgebot.bot`

### 502 Bad Gateway
**Cause:** Backend not running or wrong port

**Fix:**
```bash
pm2 status  # Check if backend is running
sudo lsof -i :5070  # Check if port is in use
pm2 logs kludgebot-5070  # Check for errors
pm2 restart kludgebot-5070  # Restart backend
```

### React Router 404s
**Cause:** Missing rewrite rules in Apache

**Fix:** Add to Apache config:
```apache
RewriteEngine On
RewriteBase /
RewriteRule ^index\.html$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]
```

---

## ✅ Success Criteria

Your migration is successful when:

- ✅ Site loads over HTTPS (green lock)
- ✅ Frontend displays correctly
- ✅ API calls work (check /api/health or similar)
- ✅ PM2 shows backend online
- ✅ No errors in logs
- ✅ Survives server reboot (PM2 auto-starts)
- ✅ Deploy script works for updates

---

**Good luck! Start with kludgebot.bot, then migrate production apps one by one.** 🚀

---

## 🎉 MIGRATION COMPLETION STATUS - kludgebot.com

**Completion Date:** October 14, 2025  
**Status:** ✅ **FULLY OPERATIONAL**

### Infrastructure Setup ✅

| Component | Status | Details |
|-----------|--------|---------|
| **Server** | ✅ Complete | OVH Ubuntu 24.04.3 LTS |
| **Node.js** | ✅ v20.19.5 | Upgraded from IONOS v18.20.8 |
| **npm** | ✅ 10.8.2 | Latest version |
| **PM2** | ✅ 6.0.13 | Auto-startup enabled with systemd |
| **Apache** | ✅ 2.4.58 | All required modules enabled |
| **Certbot** | ✅ 2.9.0 | Auto-renewal configured |
| **Firewall** | ✅ UFW | Ports 22, 80, 443 open |

### Application Deployment ✅

| Aspect | Status | Details |
|--------|--------|---------|
| **Frontend** | ✅ Live | React 19 + Vite 7 at https://kludgebot.com |
| **Backend** | ✅ Running | Express 5 on port 5070, PM2 managed |
| **PM2 Process** | ✅ Online | kludgebot-5070 running stable |
| **SSL Certificate** | ✅ Valid | Let's Encrypt expires Jan 12, 2026 |
| **Domain** | ✅ Active | https://kludgebot.com and www subdomain |
| **API Endpoints** | ✅ Working | /api/health, /api/info responding |

### DNS & Cloudflare ✅

| Record Type | Status | Configuration |
|-------------|--------|---------------|
| **A Record** | ✅ Proxied | kludgebot.com → Cloudflare IPs (104.21.78.71, 172.67.217.219) |
| **A Record (www)** | ✅ Proxied | www.kludgebot.com → Cloudflare IPs |
| **AAAA Record** | ✅ Proxied | IPv6: 2604:2dc0:306::4:0:4a |
| **MX Records** | ✅ Configured | route1/2/3.mx.cloudflare.net (priorities 89, 83, 41) |
| **SPF Record** | ✅ Valid | v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all |
| **DKIM Record** | ✅ Valid | cf2024-1._domainkey with RSA key |
| **DMARC** | ✅ Enabled | Cloudflare DMARC Management active |
| **Proxy Status** | ✅ Orange Cloud | DDoS protection + CDN enabled |

**Real Server IP:** 40.160.237.83 (hidden behind Cloudflare proxy)

### Email Configuration ✅

| Feature | Status | Details |
|---------|--------|---------|
| **Incoming Email** | ✅ Working | johnny@kludgebot.com forwards to worldwidejimmy@gmail.com |
| **Outgoing Email** | ✅ Working | Gmail can send FROM johnny@kludgebot.com |
| **Email Routing** | ✅ Enabled | Cloudflare Email Routing active |
| **Gmail SMTP** | ✅ Configured | smtp.gmail.com:587 with App Password |
| **Catch-All** | ⚠️ Optional | Not configured yet (can add later) |

### Git Workflow ✅

| Component | Status | Details |
|-----------|--------|---------|
| **Repository** | ✅ Live | git@github.com:worldwidejimmy/kludgebot.git |
| **Dev Directory** | ✅ Active | ~/apps/kludgebot.dev (for development) |
| **Prod Directory** | ✅ Deployed | ~/apps/kludgebot.prod (cloned from GitHub) |
| **Commits** | ✅ Pushed | 4 commits on main branch |
| **README** | ✅ Complete | Comprehensive documentation committed |
| **Git User** | ✅ Configured | jimmy <johnny@kludgebot.com> |

### Security Features ✅

| Feature | Status | Benefit |
|---------|--------|---------|
| **SSL/TLS** | ✅ Active | HTTPS encryption, auto-renewal |
| **Cloudflare Proxy** | ✅ Enabled | Hides real server IP |
| **DDoS Protection** | ✅ Active | Cloudflare shield layer |
| **Firewall** | ✅ Active | UFW with minimal ports open |
| **Email Auth** | ✅ Complete | SPF, DKIM, DMARC configured |
| **.env Files** | ✅ Protected | Excluded from git, .env.example only |

### Performance Features ✅

| Feature | Status | Benefit |
|---------|--------|---------|
| **CDN** | ✅ Active | Cloudflare edge caching worldwide |
| **HTTP/2** | ✅ Enabled | Faster page loads |
| **Compression** | ✅ Active | Cloudflare auto-minification |
| **Static Assets** | ✅ Optimized | Served from /var/www/kludgebot.com/ |
| **PM2 Clustering** | ⚠️ Available | Can enable if needed for scale |

### Verification Tests ✅

```bash
# Website Test
$ curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://kludgebot.com
HTTP Status: 200

# API Test
$ curl -s https://kludgebot.com/api/health
{
  "status": "ok",
  "message": "Kludgebot API is running!",
  "timestamp": "2025-10-14T06:03:14.000Z"
}

# Cloudflare Proxy Test
$ curl -s -I https://kludgebot.com | grep -i "cf-ray\|server"
server: cloudflare
cf-ray: 98e4df607d3cc54c-PDX

# DNS Test (Shows Cloudflare IPs)
$ dig kludgebot.com A +short
172.67.217.219
104.21.78.71

# PM2 Status
$ pm2 list | grep kludgebot
kludgebot-5070  │ 24       │ online

# Email MX Records
$ dig kludgebot.com MX +short
89 route1.mx.cloudflare.net.
83 route2.mx.cloudflare.net.
41 route3.mx.cloudflare.net.

# SPF Record
$ dig kludgebot.com TXT +short | grep spf
"v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all"
```

### Documentation Created ✅

| Document | Location | Purpose |
|----------|----------|---------|
| **Migration Guide** | ~/apps/new-server-management/OVH-MIGRATION-GUIDE-UPDATED.md | Complete migration reference |
| **Email Setup Guide** | ~/apps/new-server-management/EMAIL-DNS-SETUP-GUIDE.md | Email forwarding & Gmail config |
| **DNS Guide** | ~/apps/new-server-management/CLOUDFLARE-DNS-STEP-BY-STEP.md | Cloudflare DNS setup |
| **Git Workflow** | ~/apps/new-server-management/GIT-WORKFLOW-GUIDE.md | Dev/prod workflow |
| **Project README** | ~/apps/kludgebot.dev/README.md | Developer documentation |
| **Port Registry** | ~/apps/app-registry.json | Port allocation tracking |

### Port Allocation Strategy

**Block of 10 per app:**
- **5000-5069:** Reserved for future IONOS migrations
- **5070-5079:** kludgebot.com
  - 5070: Production backend ✅
  - 5071: Development backend (available)
  - 5072-5079: Reserved for future kludgebot services
- **5080+:** Next available block

### Next Steps (Optional Enhancements)

- [ ] **Catch-all email:** Add wildcard forwarding rule in Cloudflare Email Routing
- [ ] **Monitoring:** Set up Uptime monitoring service
- [ ] **Backup automation:** Schedule automated backups
- [ ] **CI/CD:** GitHub Actions for auto-deploy on push
- [ ] **Rate limiting:** Configure Cloudflare rate limiting rules
- [ ] **WAF Rules:** Enable Web Application Firewall
- [ ] **Analytics:** Set up Cloudflare Web Analytics
- [ ] **DMARC Reports:** Monitor incoming DMARC reports in Gmail

### Migration from IONOS (Remaining Sites)

**Ready to migrate when needed:**
1. carboncruiser.com (Port 5000-5009 reserved)
2. fatjimmy.com (Port 5010-5019 reserved)
3. johnhorvath.com (Port 5020-5029 reserved)
4. nanoassassin.com (Port 5030-5039 reserved)
5. presidentclownshow.com (Port 5040-5049 reserved)
6. talkingyam.com (Port 5050-5059 reserved)

**Use this guide as reference for each migration!**

---

## 🏆 Mission Accomplished!

**kludgebot.com is now:**
- ✅ Live and fully operational
- ✅ Protected by Cloudflare (DDoS, CDN, caching)
- ✅ Secured with SSL/TLS
- ✅ Email sending and receiving configured
- ✅ Documented and ready for development
- ✅ Hidden behind Cloudflare proxy (server IP protected)
- ✅ Running on modern infrastructure (Ubuntu 24.04, Node 20)

**Your first OVH migration is complete!** 🚀

