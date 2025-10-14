# Git Workflow Guide for Kludgebot

## 📁 Directory Structure

```
~/apps/
├── kludgebot.dev/      ← DEVELOPMENT (work here!)
├── kludgebot.prod/     ← PRODUCTION (deploy from here)
└── app-registry.json   ← Port management
```

---

## 🎯 The Workflow

### **1. Work in Development**

```bash
cd ~/apps/kludgebot.dev

# Make changes to code
# Edit src/App.jsx, server.js, etc.

# Test locally (optional)
npm run dev
```

### **2. Commit and Push**

```bash
cd ~/apps/kludgebot.dev

# Check what changed
git status

# Add files
git add .

# Commit with message
git commit -m "Add feature X"

# Push to GitHub
git push origin main
```

### **3. Deploy to Production**

```bash
cd ~/apps/kludgebot.prod

# Pull latest code from GitHub
git pull origin main

# Install any new dependencies
npm install

# Build the frontend
npm run build

# Deploy frontend to Apache
cp -r dist/* /var/www/kludgebot.com/

# Restart backend
pm2 restart kludgebot-5070
```

---

## ⚡ Quick Deploy Script

Save this as `~/server-management/deploy-kludgebot.sh`:

```bash
#!/bin/bash
set -e

echo "🚀 Deploying kludgebot..."

cd ~/apps/kludgebot.prod

echo "📥 Pulling latest code..."
git pull origin main

echo "📦 Installing dependencies..."
npm install

echo "🔨 Building frontend..."
npm run build

echo "🌐 Deploying to Apache..."
cp -r dist/* /var/www/kludgebot.com/

echo "🔄 Restarting backend..."
pm2 restart kludgebot-5070

echo "✅ Deployment complete!"
echo "🔗 Site: https://kludgebot.com"
pm2 status kludgebot-5070
```

**Make it executable:**
```bash
chmod +x ~/server-management/deploy-kludgebot.sh
```

**Usage:**
```bash
~/server-management/deploy-kludgebot.sh
```

---

## 🔄 Complete Example Workflow

### **Scenario: Add a new feature**

```bash
# 1. Work in dev
cd ~/apps/kludgebot.dev
# Edit files...
vim src/App.jsx

# 2. Test locally (optional)
npm run dev
# Visit http://localhost:5173

# 3. Commit
git add .
git commit -m "Add new homepage feature"
git push origin main

# 4. Deploy
cd ~/apps/kludgebot.prod
git pull origin main
npm install
npm run build
cp -r dist/* /var/www/kludgebot.com/
pm2 restart kludgebot-5070

# Done! Visit https://kludgebot.com
```

---

## 📋 Rules to Follow

### ✅ DO:
- **Always work in `kludgebot.dev`**
- **Commit and push from `kludgebot.dev`**
- **Pull and deploy from `kludgebot.prod`**
- **Test locally before pushing**
- **Write meaningful commit messages**

### ❌ DON'T:
- **Never edit files directly in `kludgebot.prod`** (you'll lose changes!)
- **Don't commit from `kludgebot.prod`**
- **Don't push from `kludgebot.prod`**
- **Don't skip the build step**

---

## 🛠️ Useful Commands

### **Check Status**
```bash
# In dev - see what changed
cd ~/apps/kludgebot.dev && git status

# In prod - check if up to date
cd ~/apps/kludgebot.prod && git status
```

### **View Logs**
```bash
# Backend logs
pm2 logs kludgebot-5070

# Apache logs
sudo tail -f /var/log/apache2/kludgebot.com_error.log
```

### **Quick Test**
```bash
# Test API
curl https://kludgebot.com/api/health

# Test website
curl -I https://kludgebot.com
```

---

## 🔧 Environment Files

### **Development (.env in kludgebot.dev/)**
```env
PORT=5071
NODE_ENV=development
```

### **Production (.env in kludgebot.prod/)**
```env
PORT=5070
NODE_ENV=production
```

**Note:** `.env` files are NOT committed to git (in `.gitignore`)

---

## 📦 Package Management

### **Adding New Dependencies**

```bash
# In development
cd ~/apps/kludgebot.dev
npm install package-name
git add package.json package-lock.json
git commit -m "Add package-name dependency"
git push origin main

# Then deploy
cd ~/apps/kludgebot.prod
git pull origin main
npm install  # ← This installs the new package
npm run build
# ... rest of deployment
```

---

## 🎯 Current Git State

- **Repository:** https://github.com/worldwidejimmy/kludgebot
- **Branch:** main
- **Dev directory:** Initialized and pushed ✅
- **Prod directory:** Cloned from GitHub ✅

---

## 💡 Pro Tips

1. **Commit often** - Small, frequent commits are better
2. **Test before pushing** - Save yourself deployment headaches
3. **Use the deploy script** - Automates the whole process
4. **Check PM2 logs** - After deploying, make sure backend restarted OK
5. **Keep .env local** - Never commit secrets to git

---

## 🆘 Common Issues

### **"I edited prod by mistake!"**
```bash
cd ~/apps/kludgebot.prod
git status  # See what changed
git reset --hard origin/main  # Discard all local changes
```

### **"Git pull says there are conflicts"**
```bash
# This shouldn't happen in prod if you follow the rules
# But if it does:
cd ~/apps/kludgebot.prod
git stash  # Save your changes (shouldn't have any!)
git pull origin main
```

### **"Backend won't start after deploy"**
```bash
pm2 logs kludgebot-5070  # Check the error
cd ~/apps/kludgebot.prod
npm install  # Make sure dependencies are installed
pm2 restart kludgebot-5070
```

---

**Remember: Dev → Git → Prod → Deploy!** 🚀
