# Server Migration Guide: IONOS → OVH/Cloudflare

**Migration from IONOS (Ubuntu 20.04) to OVH (Ubuntu 24.04) with Cloudflare DNS**

**Prepared:** October 14, 2025  
**Current Server:** IONOS Ubuntu 20.04.6 LTS (root user)  
**New Server:** OVH Ubuntu 24.04.3 LTS (ubuntu user)  
**First Domain to Setup:** kludgebot.bot

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [User Account Strategy](#user-account-strategy)
3. [Directory Structure](#directory-structure)
4. [Initial Server Setup](#initial-server-setup)
5. [Installing Core Dependencies](#installing-core-dependencies)
6. [Setting Up Your First App (kludgebot.bot)](#setting-up-your-first-app)
7. [Apache Configuration](#apache-configuration)
8. [SSL Certificate Setup](#ssl-certificate-setup)
9. [Port Management](#port-management)
10. [PM2 Process Management](#pm2-process-management)
11. [Git Repository Setup](#git-repository-setup)
12. [Deployment Workflow](#deployment-workflow)
13. [Migration Checklist](#migration-checklist)
14. [Reference Documentation](#reference-documentation)

---

## 🎯 Overview

### Current Server Architecture (IONOS)

**Key Patterns Established:**
- ✅ `/opt/apps/` for all application code (dev/prod separation)
- ✅ `/root/jimmy-server-management/` for scripts and documentation
- ✅ PM2 for Node.js process management
- ✅ Apache reverse proxy for frontend + API routing
- ✅ Port allocation strategy (blocks of 10 per app)
- ✅ Centralized app registry (`app-registry.json`)
- ✅ Dev/Prod separation with `.dev` and `.prod` directories
- ✅ FatJimmy Dashboard for dev management (fatjimmy.com)
- ✅ Let's Encrypt SSL automation

**Current Apps:**
- nanoassassin.com (Ports 5000 prod, 5001 dev)
- presidentclownshow.com/blurbrank (Ports 5010 prod, 5011 dev)
- fatjimmy.com (Dashboard - Port 5020)
- Experimental apps on ports 5030-5060

---

## 👤 User Account Strategy

### Recommendation: Use `ubuntu` User for Everything

**Why `ubuntu` instead of `root`?**

✅ **Security Best Practices:**
- Root should only be used for system administration
- Ubuntu's default `ubuntu` user has sudo privileges
- Reduces risk of accidental system-wide changes

✅ **Cloud Provider Standards:**
- OVH provides `ubuntu` user by default
- Most cloud providers discourage direct root login
- Easier to follow online tutorials and docs

✅ **Easy Transition:**
- You're already doing everything as root on IONOS
- On OVH, just prefix commands with `sudo` when needed
- No need to create additional users initially

**Simple Rule:**
```bash
# On new OVH server, use ubuntu for everything
sudo command      # For system changes (Apache, PM2 global install, etc.)
command           # For your own files in /home/ubuntu/

# Later, if you want separate user for apps:
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG sudo deploy
```

**For This Guide:**
- All commands assume you're logged in as `ubuntu`
- Use `sudo` where system privileges are needed
- Your apps will live in `/home/ubuntu/apps/` or `/opt/apps/`

---

## 📁 Directory Structure

### Recommended Structure for OVH Server

```
/home/ubuntu/
├── apps/                          # All your React/Node apps
│   ├── kludgebot.dev/            # Development version (work here)
│   │   ├── .git/
│   │   ├── client/               # React/Vite frontend
│   │   ├── server/               # Node.js backend
│   │   ├── .env                  # Dev environment variables
│   │   └── package.json
│   │
│   ├── kludgebot.prod/           # Production version (deploy from here)
│   │   ├── .git/
│   │   ├── dist/                 # Built files
│   │   │   ├── index.js         # Backend (PM2 runs this)
│   │   │   └── public/          # Frontend static files
│   │   ├── .env                  # Prod environment variables
│   │   └── package.json
│   │
│   ├── nanoassassin.dev/         # Future migration
│   ├── nanoassassin.prod/
│   ├── app-registry.json         # Central app configuration
│   ├── get-port.sh               # Port lookup helper
│   └── pm2-ecosystem.config.js   # PM2 configuration
│
├── server-management/            # Server docs & scripts
│   ├── README.md
│   ├── PORT-MANAGEMENT.md
│   ├── PROJECT-STRUCTURE.md
│   ├── CERTIFICATES.md
│   ├── backup-websites.sh
│   ├── check-env-sync.sh
│   ├── port-registry.conf
│   └── deploy.sh                 # Deployment automation
│
└── backups/                      # Automated backups

/var/www/
├── kludgebot.bot/
│   └── html/                     # Frontend served from here
│       └── [symlink to prod build or direct copy]
│
└── [future domains]/

/etc/apache2/
├── sites-available/
│   ├── kludgebot.bot.conf
│   └── kludgebot.bot-le-ssl.conf
└── sites-enabled/
    └── [symlinks to active sites]
```

**Key Differences from Current Server:**
- Using `/home/ubuntu/apps/` instead of `/opt/apps/` (easier permissions)
- Server management in `/home/ubuntu/server-management/` (no root directory)
- Everything owned by `ubuntu:ubuntu` instead of mix of `root` and `www-data`

**Alternative: Keep `/opt/apps/` Pattern**

If you prefer the current structure:
```bash
sudo mkdir -p /opt/apps
sudo chown ubuntu:ubuntu /opt/apps
```

Both approaches work. `/home/ubuntu/apps/` is simpler for a single user.

---

## 🚀 Initial Server Setup

### Step 1: First Login

```bash
# From your local machine
ssh ubuntu@your-ovh-ip
```

### Step 2: Update System

```bash
sudo apt update
sudo apt upgrade -y
```

### Step 3: Create Directory Structure

```bash
# Create main directories
mkdir -p ~/apps
mkdir -p ~/server-management
mkdir -p ~/backups

# Or use /opt/apps/ pattern like current server
sudo mkdir -p /opt/apps
sudo chown ubuntu:ubuntu /opt/apps
mkdir -p ~/server-management
mkdir -p ~/backups
```

### Step 4: Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Set up SSH key for GitHub
ssh-keygen -t ed25519 -C "your.email@example.com"
cat ~/.ssh/id_ed25519.pub
# Copy this and add to GitHub: https://github.com/settings/keys
```

### Step 5: Basic Security

```bash
# Configure firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Apache Full'  # Allows ports 80 and 443
sudo ufw enable

# Check status
sudo ufw status
```

---

## 📦 Installing Core Dependencies

### Step 1: Install Node.js

```bash
# Install Node.js 20.x (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify
node --version  # Should show v20.x.x
npm --version
```

### Step 2: Install PM2

```bash
# Install PM2 globally
sudo npm install -g pm2

# Verify
pm2 --version

# Set up PM2 to start on boot
pm2 startup
# This will output a command - copy and run it
# Usually: sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu
```

### Step 3: Install Apache

```bash
# Install Apache
sudo apt install -y apache2

# Enable required modules
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod rewrite
sudo a2enmod ssl
sudo a2enmod headers

# Restart Apache
sudo systemctl restart apache2

# Verify
sudo systemctl status apache2
apache2 -v  # Should show Apache 2.4.x
```

### Step 4: Install Certbot (Let's Encrypt)

```bash
# Install Certbot with Apache plugin
sudo apt install -y certbot python3-certbot-apache

# Verify
certbot --version
```

### Step 5: Install Additional Tools

```bash
# Useful utilities
sudo apt install -y jq curl wget git htop

# Optional but useful
sudo apt install -y build-essential  # For native npm modules
```

---

## 🎨 Setting Up Your First App (kludgebot.bot)

### Option A: Create New React+Vite App

```bash
cd ~/apps  # or /opt/apps if using that pattern

# Create new Vite app
npm create vite@latest kludgebot.dev -- --template react-ts
cd kludgebot.dev
npm install

# Set up basic structure
mkdir server
```

**Create server/index.ts:**
```typescript
import express from 'express';
import { createServer as createViteServer } from 'vite';

const app = express();
const PORT = process.env.PORT || 5070;

app.use(express.json());

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Your API routes here
app.get('/api/hello', (req, res) => {
  res.json({ message: 'Hello from kludgebot!' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📝 API available at http://localhost:${PORT}/api/`);
});
```

**Add dependencies:**
```bash
npm install express
npm install -D @types/express tsx
```

**Update package.json scripts:**
```json
{
  "scripts": {
    "dev": "tsx watch server/index.ts",
    "dev:frontend": "vite",
    "build": "tsc && vite build && tsc --project tsconfig.server.json",
    "preview": "vite preview",
    "start": "node dist/index.js"
  }
}
```

**Create .env:**
```bash
echo "PORT=5070" > .env
echo "NODE_ENV=development" >> .env
```

### Option B: Clone Existing Repository

```bash
cd ~/apps

# Clone your repo
git clone git@github.com:yourusername/kludgebot.git kludgebot.dev
cd kludgebot.dev
npm install

# Create .env
echo "PORT=5070" > .env
echo "NODE_ENV=development" >> .env
```

### Step 2: Test Development Server

```bash
cd ~/apps/kludgebot.dev

# Test backend
npm run dev
# Should see: 🚀 Server running on http://localhost:5070

# In another terminal, test frontend
npm run dev:frontend
# Should see Vite dev server on port 5173
```

### Step 3: Create Production Clone

```bash
cd ~/apps

# Clone for production
git clone git@github.com:yourusername/kludgebot.git kludgebot.prod
cd kludgebot.prod
npm install

# Build
npm run build

# Create production .env
echo "PORT=5070" > .env
echo "NODE_ENV=production" >> .env
```

---

## 🌐 Apache Configuration

### Step 1: Create Initial HTTP Configuration

```bash
sudo nano /etc/apache2/sites-available/kludgebot.bot.conf
```

**Add:**
```apache
<VirtualHost *:80>
    ServerAdmin admin@kludgebot.bot
    ServerName kludgebot.bot
    ServerAlias www.kludgebot.bot
    DocumentRoot /var/www/kludgebot.bot/html

    ErrorLog ${APACHE_LOG_DIR}/kludgebot-error.log
    CustomLog ${APACHE_LOG_DIR}/kludgebot-access.log combined
</VirtualHost>
```

### Step 2: Create Web Directory

```bash
sudo mkdir -p /var/www/kludgebot.bot/html
sudo chown -R ubuntu:ubuntu /var/www/kludgebot.bot
```

### Step 3: Enable Site

```bash
# Enable the site
sudo a2ensite kludgebot.bot.conf

# Test configuration
sudo apache2ctl configtest
# Should say "Syntax OK"

# Reload Apache
sudo systemctl reload apache2
```

### Step 4: Deploy Frontend

```bash
# Copy built files to web directory
cp -r ~/apps/kludgebot.prod/dist/public/* /var/www/kludgebot.bot/html/

# Or create symlink (more dynamic)
# sudo ln -sf ~/apps/kludgebot.prod/dist/public/* /var/www/kludgebot.bot/html/
```

### Step 5: Configure Reverse Proxy (After SSL)

After getting SSL certificate, you'll update to include backend proxy:

```apache
<VirtualHost *:443>
    ServerAdmin admin@kludgebot.bot
    ServerName kludgebot.bot
    ServerAlias www.kludgebot.bot
    DocumentRoot /var/www/kludgebot.bot/html

    # Proxy API requests to Node backend
    ProxyPreserveHost On
    ProxyPass /api http://localhost:5070/api
    ProxyPassReverse /api http://localhost:5070/api

    # Serve React app for all other routes
    <Directory /var/www/kludgebot.bot/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # React Router - send all requests to index.html
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/kludgebot-error.log
    CustomLog ${APACHE_LOG_DIR}/kludgebot-access.log combined

    SSLCertificateFile /etc/letsencrypt/live/kludgebot.bot/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/kludgebot.bot/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
```

---

## 🔒 SSL Certificate Setup

### Prerequisites

1. **DNS must point to your server** (configure in Cloudflare first)
2. **Port 80 must be open** (check with `sudo ufw status`)
3. **Domain must be accessible** (test: `curl http://kludgebot.bot`)

### Cloudflare DNS Setup

Before running Certbot:

1. Log into Cloudflare
2. Add `kludgebot.bot` domain
3. Create DNS records:
   ```
   Type: A
   Name: @
   Content: your-ovh-server-ip
   Proxy: OFF (orange cloud disabled) - Important for initial setup!
   
   Type: A
   Name: www
   Content: your-ovh-server-ip
   Proxy: OFF
   ```
4. Wait for DNS propagation (use `dig kludgebot.bot` to check)

### Install SSL Certificate

```bash
# Get certificate with automatic Apache configuration
sudo certbot --apache -d kludgebot.bot -d www.kludgebot.bot --redirect

# This will:
# 1. Request certificate from Let's Encrypt
# 2. Validate domain ownership
# 3. Create SSL configuration file
# 4. Set up HTTP→HTTPS redirect
# 5. Reload Apache
```

### After SSL Installation

```bash
# Check certificate status
sudo certbot certificates

# Test renewal
sudo certbot renew --dry-run

# Check auto-renewal timer
sudo systemctl status certbot.timer
```

### Enable Cloudflare Proxy (Optional)

After SSL is working:
1. Go back to Cloudflare DNS
2. Enable proxy (click orange cloud icon) for both @ and www records
3. This adds Cloudflare's CDN and DDoS protection

---

## 🎯 Port Management

### Port Allocation Strategy

Follow the same pattern from current server:

**Block of 10 per app (Base Port = App Slot × 10 + 5000)**

| Range | App | Dev Port | Prod Port |
|-------|-----|----------|-----------|
| 5000-5009 | Reserved (future) | - | - |
| 5010-5019 | Reserved (future) | - | - |
| 5020-5029 | Reserved (future) | - | - |
| ... | | | |
| 5070-5079 | **kludgebot** | 5070 | 5070 (same for now) |
| 5080-5089 | Next app | 5080 | 5080 |
| 5090-5099 | Next app | 5090 | 5090 |

### Create App Registry

```bash
nano ~/apps/app-registry.json
```

**Content:**
```json
{
  "apps": {
    "kludgebot": {
      "name": "Kludgebot",
      "dev": {
        "port": 5070,
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
      "5070-5079": "kludgebot"
    }
  }
}
```

### Create Port Helper Script

```bash
nano ~/apps/get-port.sh
```

**Content:**
```bash
#!/bin/bash
# Get port for an app from registry

REGISTRY_FILE="$(dirname "$0")/app-registry.json"
APP_NAME="$1"
MODE="${2:-dev}"  # Default to dev

if [ ! -f "$REGISTRY_FILE" ]; then
    echo "ERROR: Registry file not found" >&2
    exit 1
fi

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app-name> [dev|prod]" >&2
    exit 1
fi

# Extract port using jq
PORT=$(jq -r ".apps.\"$APP_NAME\".\"$MODE\".port" "$REGISTRY_FILE")

if [ "$PORT" = "null" ] || [ -z "$PORT" ]; then
    echo "ERROR: Port not found for $APP_NAME ($MODE)" >&2
    exit 1
fi

echo "$PORT"
```

**Make executable:**
```bash
chmod +x ~/apps/get-port.sh
```

**Usage:**
```bash
~/apps/get-port.sh kludgebot dev   # Returns: 5070
~/apps/get-port.sh kludgebot prod  # Returns: 5070
```

---

## ⚡ PM2 Process Management

### Create PM2 Ecosystem File

```bash
nano ~/apps/pm2-ecosystem.config.js
```

**Content:**
```javascript
module.exports = {
  apps: [
    // PRODUCTION APPS (always running)
    {
      name: 'kludgebot-5070',
      script: 'dist/index.js',
      cwd: '/home/ubuntu/apps/kludgebot.prod',
      env: {
        NODE_ENV: 'production',
        PORT: 5070
      },
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      error_file: '/home/ubuntu/apps/kludgebot.prod/error.log',
      out_file: '/home/ubuntu/apps/kludgebot.prod/out.log',
      time: true
    },
    
    // DEVELOPMENT APPS (manual start)
    {
      name: 'kludgebot-dev',
      script: 'npm',
      args: 'run dev',
      cwd: '/home/ubuntu/apps/kludgebot.dev',
      env: {
        NODE_ENV: 'development',
        PORT: 5071  // Different port for dev if running simultaneously
      },
      instances: 1,
      autorestart: false,
      watch: false,
      max_memory_restart: '500M'
    }
  ]
};
```

### Start Production App

```bash
# Start using ecosystem file
pm2 start ~/apps/pm2-ecosystem.config.js --only kludgebot-5070

# Or start directly
cd ~/apps/kludgebot.prod
PORT=5070 pm2 start dist/index.js --name kludgebot-5070

# Save PM2 configuration
pm2 save

# Check status
pm2 status
pm2 logs kludgebot-5070
```

### Common PM2 Commands

```bash
# List all processes
pm2 list

# Start specific app
pm2 start kludgebot-5070

# Stop specific app
pm2 stop kludgebot-5070

# Restart app (zero-downtime)
pm2 restart kludgebot-5070

# Delete app from PM2
pm2 delete kludgebot-5070

# View logs
pm2 logs kludgebot-5070
pm2 logs kludgebot-5070 --lines 50

# Monitor all apps
pm2 monit

# Save current process list
pm2 save

# Resurrect saved processes (after reboot)
pm2 resurrect
```

---

## 📚 Git Repository Setup

### Initialize Repository (If New Project)

```bash
cd ~/apps/kludgebot.dev

# Initialize git
git init
git add .
git commit -m "Initial commit"

# Create repo on GitHub, then:
git branch -M main
git remote add origin git@github.com:yourusername/kludgebot.git
git push -u origin main
```

### Clone Existing Repository

```bash
cd ~/apps

# Clone for development
git clone git@github.com:yourusername/kludgebot.git kludgebot.dev

# Clone for production
git clone git@github.com:yourusername/kludgebot.git kludgebot.prod
```

### .gitignore Setup

Ensure your `.gitignore` includes:
```
node_modules/
dist/
.env
.env.*
*.log
.DS_Store
```

---

## 🚀 Deployment Workflow

### Manual Deployment

```bash
# 1. Work in dev
cd ~/apps/kludgebot.dev
# Make changes, test locally
npm run dev

# 2. Commit and push
git add .
git commit -m "Add new feature"
git push origin main

# 3. Update production
cd ~/apps/kludgebot.prod
git pull origin main
npm install  # If dependencies changed
npm run build

# 4. Deploy frontend
cp -r dist/public/* /var/www/kludgebot.bot/html/

# 5. Restart backend
pm2 restart kludgebot-5070

# 6. Verify
pm2 logs kludgebot-5070 --lines 20
curl https://kludgebot.bot/api/health
```

### Automated Deployment Script

```bash
nano ~/server-management/deploy.sh
```

**Content:**
```bash
#!/bin/bash

# Deployment script for React+Node apps
# Usage: ./deploy.sh <app-name> <domain>

set -e  # Exit on error

APP_NAME="$1"
DOMAIN="$2"

if [ -z "$APP_NAME" ] || [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <app-name> <domain>"
    echo "Example: $0 kludgebot kludgebot.bot"
    exit 1
fi

PROD_DIR="$HOME/apps/${APP_NAME}.prod"
WEB_DIR="/var/www/${DOMAIN}/html"
PM2_NAME="${APP_NAME}-$(jq -r ".apps.\"$APP_NAME\".prod.port" "$HOME/apps/app-registry.json")"

echo "🚀 Deploying ${APP_NAME} to ${DOMAIN}..."
echo ""

# Check if prod directory exists
if [ ! -d "$PROD_DIR" ]; then
    echo "❌ ERROR: Production directory not found: $PROD_DIR"
    exit 1
fi

# Update code
echo "📥 Pulling latest code..."
cd "$PROD_DIR"
git pull origin main

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build
echo "🔨 Building project..."
npm run build

# Deploy frontend
echo "🌐 Deploying frontend to ${WEB_DIR}..."
rm -rf "$WEB_DIR"/*
cp -r dist/public/* "$WEB_DIR/"

# Restart backend
echo "🔄 Restarting backend (${PM2_NAME})..."
pm2 restart "$PM2_NAME"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 PM2 Status:"
pm2 status "$PM2_NAME"

echo ""
echo "🔗 Site: https://${DOMAIN}"
echo "🔍 Logs: pm2 logs ${PM2_NAME}"
```

**Make executable:**
```bash
chmod +x ~/server-management/deploy.sh
```

**Usage:**
```bash
~/server-management/deploy.sh kludgebot kludgebot.bot
```

---

## ✅ Migration Checklist

### Phase 1: Initial Setup (kludgebot.bot)

- [ ] Log into OVH server as ubuntu
- [ ] Update system: `sudo apt update && sudo apt upgrade`
- [ ] Create directory structure
- [ ] Configure Git and SSH keys
- [ ] Set up firewall (ufw)
- [ ] Install Node.js 20.x
- [ ] Install PM2 globally
- [ ] Install Apache and modules
- [ ] Install Certbot
- [ ] Create app-registry.json
- [ ] Create get-port.sh helper
- [ ] Create pm2-ecosystem.config.js

### Phase 2: First App Deployment

- [ ] Create or clone kludgebot.dev
- [ ] Create kludgebot.prod
- [ ] Build production version
- [ ] Create Apache HTTP config
- [ ] Enable site and test
- [ ] Configure DNS in Cloudflare (Proxy OFF)
- [ ] Wait for DNS propagation
- [ ] Install SSL certificate with Certbot
- [ ] Update Apache config with proxy rules
- [ ] Deploy frontend to /var/www/
- [ ] Start backend with PM2
- [ ] Test site (https://kludgebot.bot)
- [ ] Enable Cloudflare proxy (optional)
- [ ] Save PM2 configuration

### Phase 3: Documentation & Scripts

- [ ] Copy documentation to ~/server-management/
  - [ ] README.md
  - [ ] PORT-MANAGEMENT.md
  - [ ] PROJECT-STRUCTURE.md
  - [ ] CERTIFICATES.md
- [ ] Create deploy.sh script
- [ ] Create backup script
- [ ] Test deployment workflow
- [ ] Document any customizations

### Phase 4: Future App Migrations

For each app you migrate from IONOS:

- [ ] Clone .dev and .prod versions
- [ ] Update app-registry.json (add app, assign ports)
- [ ] Update pm2-ecosystem.config.js
- [ ] Create Apache config
- [ ] Point DNS to new server (Cloudflare)
- [ ] Install SSL certificate
- [ ] Deploy frontend and start backend
- [ ] Test thoroughly
- [ ] Update old server to show "migrated" notice

---

## 📖 Reference Documentation

### Port Management Pattern

```
Port = (App Slot × 10) + 5000

Slot 1:  5000-5009  (reserved for future nanoassassin)
Slot 2:  5010-5019  (reserved for future blurbrank)
Slot 3:  5020-5029  (reserved for future fatjimmy-dashboard)
Slot 4:  5030-5039  (reserved)
Slot 5:  5040-5049  (reserved)
Slot 6:  5050-5059  (reserved)
Slot 7:  5060-5069  (reserved)
Slot 8:  5070-5079  ← kludgebot (first app on new server)
Slot 9:  5080-5089  (available)
Slot 10: 5090-5099  (available)
```

### File Permissions

```bash
# Web directory (Apache needs read access)
sudo chown -R ubuntu:ubuntu /var/www/kludgebot.bot
sudo find /var/www/kludgebot.bot -type d -exec chmod 755 {} \;
sudo find /var/www/kludgebot.bot -type f -exec chmod 644 {} \;

# App directory (your code)
chown -R ubuntu:ubuntu ~/apps/
chmod 755 ~/apps/
```

### Environment Variables

**Development (.env in app.dev/):**
```env
PORT=5071
NODE_ENV=development
DATABASE_URL=postgresql://localhost:5432/kludgebot_dev
API_URL=http://localhost:5071
```

**Production (.env in app.prod/):**
```env
PORT=5070
NODE_ENV=production
DATABASE_URL=postgresql://localhost:5432/kludgebot
API_URL=https://kludgebot.bot
```

### Apache Virtual Host Template

```apache
<VirtualHost *:443>
    ServerAdmin admin@DOMAIN
    ServerName DOMAIN
    ServerAlias www.DOMAIN
    DocumentRoot /var/www/DOMAIN/html

    # Backend API proxy
    ProxyPreserveHost On
    ProxyPass /api http://localhost:PORT/api
    ProxyPassReverse /api http://localhost:PORT/api

    # Frontend
    <Directory /var/www/DOMAIN/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/APPNAME-error.log
    CustomLog ${APACHE_LOG_DIR}/APPNAME-access.log combined

    SSLCertificateFile /etc/letsencrypt/live/DOMAIN/fullchain.pem
    SSLCertificateKeyKey /etc/letsencrypt/live/DOMAIN/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
```

### PM2 App Template

```javascript
{
  name: 'appname-PORT',
  script: 'dist/index.js',
  cwd: '/home/ubuntu/apps/appname.prod',
  env: {
    NODE_ENV: 'production',
    PORT: PORT
  },
  instances: 1,
  autorestart: true,
  watch: false,
  max_memory_restart: '500M',
  error_file: '/home/ubuntu/apps/appname.prod/error.log',
  out_file: '/home/ubuntu/apps/appname.prod/out.log',
  time: true
}
```

### Useful Commands Reference

```bash
# System
sudo systemctl status apache2
sudo systemctl reload apache2
sudo systemctl restart apache2
sudo apache2ctl configtest
sudo ufw status

# PM2
pm2 list
pm2 status
pm2 logs appname --lines 50
pm2 restart appname
pm2 stop appname
pm2 delete appname
pm2 save
pm2 startup

# Certbot
sudo certbot certificates
sudo certbot renew --dry-run
sudo certbot --apache -d domain.com -d www.domain.com --redirect

# Logs
sudo tail -f /var/log/apache2/error.log
sudo tail -f /var/log/apache2/appname-error.log
pm2 logs appname

# Ports
sudo netstat -tlnp | grep node
sudo lsof -i :5070

# Git
git status
git pull origin main
git log --oneline -10
```

---

## �� Quick Start: Setting Up kludgebot.bot

Here's the condensed version for getting kludgebot.bot running:

```bash
# 1. SYSTEM SETUP
sudo apt update && sudo apt upgrade -y
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs apache2 certbot python3-certbot-apache
sudo npm install -g pm2
pm2 startup  # Run the command it outputs

# 2. DIRECTORY STRUCTURE
mkdir -p ~/apps ~/server-management ~/backups

# 3. CREATE OR CLONE APP
cd ~/apps
# Option A: New app
npm create vite@latest kludgebot.dev -- --template react-ts
# Option B: Clone existing
git clone git@github.com:user/kludgebot.git kludgebot.dev

# Clone for production
git clone git@github.com:user/kludgebot.git kludgebot.prod

# 4. BUILD PRODUCTION
cd ~/apps/kludgebot.prod
npm install
echo "PORT=5070" > .env
npm run build

# 5. APACHE CONFIG
sudo mkdir -p /var/www/kludgebot.bot/html
sudo chown ubuntu:ubuntu /var/www/kludgebot.bot
sudo nano /etc/apache2/sites-available/kludgebot.bot.conf
# [Paste basic HTTP config from guide above]
sudo a2ensite kludgebot.bot.conf
sudo apache2ctl configtest
sudo systemctl reload apache2

# 6. DEPLOY FRONTEND
cp -r ~/apps/kludgebot.prod/dist/public/* /var/www/kludgebot.bot/html/

# 7. CONFIGURE DNS IN CLOUDFLARE
# Point kludgebot.bot and www.kludgebot.bot to server IP
# Set Proxy to OFF (orange cloud disabled)
# Wait for DNS propagation

# 8. INSTALL SSL
sudo certbot --apache -d kludgebot.bot -d www.kludgebot.bot --redirect

# 9. UPDATE APACHE WITH PROXY
sudo nano /etc/apache2/sites-available/kludgebot.bot-le-ssl.conf
# [Add ProxyPass rules from guide above]
sudo apache2ctl configtest
sudo systemctl reload apache2

# 10. START BACKEND WITH PM2
cd ~/apps/kludgebot.prod
PORT=5070 pm2 start dist/index.js --name kludgebot-5070
pm2 save

# 11. TEST
curl https://kludgebot.bot/api/health
pm2 logs kludgebot-5070

# 12. ENABLE CLOUDFLARE PROXY (OPTIONAL)
# Go back to Cloudflare, enable proxy (orange cloud)
```

Done! Your first app is running on the new server with the same patterns as the old one.

---

## 🔄 Migrating Additional Apps

Once kludgebot is running, migrating additional apps follows this pattern:

1. **Clone app** (dev and prod versions)
2. **Update app-registry.json** (add app entry, assign port)
3. **Update pm2-ecosystem.config.js** (add PM2 config)
4. **Create Apache config** (follow template)
5. **Configure DNS** in Cloudflare (point to new server)
6. **Install SSL** certificate
7. **Deploy frontend** to /var/www/
8. **Start backend** with PM2
9. **Test thoroughly**
10. **Update old server** with redirect or "migrated" message

---

## 📝 Notes from Current Server

### Proven Patterns to Keep

✅ **Dev/Prod Separation**: `.dev` and `.prod` directories work great  
✅ **Port Blocks**: 10 ports per app gives room to grow  
✅ **App Registry**: Single source of truth for configuration  
✅ **PM2 Ecosystem**: Easy to manage all processes  
✅ **Apache Proxy**: Clean separation of frontend/backend  
✅ **Git Everywhere**: Version control for all apps  
✅ **Automated SSL**: Let's Encrypt + Certbot just works  

### Things to Potentially Improve

🔄 **User Permissions**: Using ubuntu user cleaner than mixed root/www-data  
🔄 **Deployment Script**: Automate the deploy process from day 1  
🔄 **Backup Script**: Set up automated backups early  
🔄 **Monitoring**: Consider adding uptime monitoring (UptimeRobot, etc.)  
🔄 **Logs**: Centralize log management (could use PM2 log rotation)  

### FatJimmy Dashboard

The dashboard is super useful for managing multiple apps. Consider migrating it early (after 2-3 apps are running) as it makes managing the server much easier.

---

## 🆘 Troubleshooting

### Can't SSH into Server
```bash
# Check if server is running
ping your-server-ip

# Try with verbose output
ssh -v ubuntu@your-server-ip

# Check SSH key
ssh-add -l
```

### Port Already in Use
```bash
# Find what's using the port
sudo lsof -i :5070

# Kill specific process
kill <PID>

# Or use PM2
pm2 delete process-name
```

### Apache Won't Start
```bash
# Check for errors
sudo apache2ctl configtest

# View detailed error
sudo systemctl status apache2
sudo tail -50 /var/log/apache2/error.log

# Common fixes
sudo a2enmod proxy proxy_http rewrite ssl
sudo systemctl restart apache2
```

### SSL Certificate Fails
```bash
# Check DNS is pointing to server
dig kludgebot.bot
nslookup kludgebot.bot

# Verify port 80 is accessible
curl http://kludgebot.bot

# Check Certbot logs
sudo tail -50 /var/log/letsencrypt/letsencrypt.log

# Try manual mode
sudo certbot certonly --manual -d kludgebot.bot
```

### PM2 Process Won't Start
```bash
# Check logs
pm2 logs appname --lines 100

# Try starting manually
cd ~/apps/appname.prod
node dist/index.js

# Check environment
pm2 show appname

# Delete and recreate
pm2 delete appname
pm2 start dist/index.js --name appname
```

### Site Shows 502 Bad Gateway
```bash
# Backend is probably not running
pm2 status

# Check if port is listening
sudo lsof -i :5070

# Restart backend
pm2 restart appname

# Check logs
pm2 logs appname
sudo tail -f /var/log/apache2/appname-error.log
```

---

## 🎉 Success Criteria

You'll know the migration is successful when:

✅ kludgebot.bot loads over HTTPS  
✅ Frontend displays correctly  
✅ API calls work (`/api/health` returns JSON)  
✅ PM2 shows backend running and healthy  
✅ SSL certificate is valid (green lock in browser)  
✅ Logs show no errors  
✅ You can deploy updates using the workflow  
✅ Server survives reboot (PM2 auto-starts)  

---

## 📚 Additional Resources

- **Current Server Docs**: All the .md files in `/root/jimmy-server-management/`
- **PM2 Docs**: https://pm2.keymetrics.io/docs/
- **Apache Docs**: https://httpd.apache.org/docs/2.4/
- **Certbot**: https://certbot.eff.org/
- **Cloudflare**: https://www.cloudflare.com/learning/
- **Vite**: https://vitejs.dev/guide/
- **Express**: https://expressjs.com/

---

**Good luck with your migration! 🚀**

*This guide is based on your current IONOS server setup and adapted for OVH with best practices for Ubuntu 24.04.*
