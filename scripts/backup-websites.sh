#!/bin/bash

# Website and Apache Configuration Backup Script
# Creates timestamped backups and checks git status for uncommitted changes

# Configuration
BACKUP_DIR="/home/ubuntu/backups"
APPS_DIR="/home/ubuntu/apps"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
KEEP_BACKUPS=5  # Number of backups to keep

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "==========================================="
echo "Backup & Git Status Check"
echo "Started: $(date)"
echo "==========================================="
echo ""

# Check git status for all repos in $APPS_DIR
echo "Checking Git Status for All Projects..."
echo "==========================================="
UNCOMMITTED_FOUND=false

shopt -s nullglob
for dir in "$APPS_DIR"/*.dev "$APPS_DIR"/*.prod; do
    if [ -d "$dir/.git" ]; then
        PROJECT=$(basename "$dir")
        cd "$dir" || continue
        
        # Check if there are uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            echo "⚠️  $PROJECT: HAS UNCOMMITTED CHANGES"
            UNCOMMITTED_FOUND=true
            git status --short | head -10
            echo ""
        else
            # Check if there are untracked files
            UNTRACKED=$(git ls-files --others --exclude-standard | wc -l)
            if [ "$UNTRACKED" -gt 0 ]; then
                echo "⚠️  $PROJECT: Has $UNTRACKED untracked files"
                UNCOMMITTED_FOUND=true
                git ls-files --others --exclude-standard | head -5
                echo ""
            else
                echo "✓ $PROJECT: Clean (all committed)"
            fi
        fi
    fi
done
shopt -u nullglob

if [ "$UNCOMMITTED_FOUND" = false ]; then
    echo "✓ All projects are clean!"
fi
echo ""

# Backup critical configuration files
echo "Backing up Configuration Files..."
echo "==========================================="

# Backup app registry (single source of truth for ports)
if [ -f "$APPS_DIR/app-registry.json" ]; then
    cp "$APPS_DIR/app-registry.json" "$BACKUP_DIR/app-registry-$TIMESTAMP.json"
    echo "✓ App registry backed up: app-registry-$TIMESTAMP.json"
fi

# Backup Apache configuration
echo "Backing up Apache configuration..."
tar -czf "$BACKUP_DIR/apache2-config-$TIMESTAMP.tar.gz" /etc/apache2/ 2>/dev/null
if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_DIR/apache2-config-$TIMESTAMP.tar.gz" | cut -f1)
    echo "✓ Apache config backed up: apache2-config-$TIMESTAMP.tar.gz ($SIZE)"
fi

# Backup website static files (not in git repos)
echo "Backing up /var/www/ static files..."
tar -czf "$BACKUP_DIR/www-static-$TIMESTAMP.tar.gz" /var/www/ 2>/dev/null
if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_DIR/www-static-$TIMESTAMP.tar.gz" | cut -f1)
    echo "✓ Static files backed up: www-static-$TIMESTAMP.tar.gz ($SIZE)"
fi

# Backup PM2 configuration
PM2_DUMP="/home/ubuntu/.pm2/dump.pm2"
if [ -f "$PM2_DUMP" ]; then
    cp "$PM2_DUMP" "$BACKUP_DIR/pm2-dump-$TIMESTAMP.json"
    echo "✓ PM2 config backed up: pm2-dump-$TIMESTAMP.json"
fi

# Backup server management scripts
SERVER_MGMT_DIR="/home/ubuntu/apps/new-server-management"
if [ -d "$SERVER_MGMT_DIR" ]; then
    tar -czf "$BACKUP_DIR/server-management-$TIMESTAMP.tar.gz" "$SERVER_MGMT_DIR" 2>/dev/null
    if [ $? -eq 0 ]; then
        SIZE=$(du -sh "$BACKUP_DIR/server-management-$TIMESTAMP.tar.gz" | cut -f1)
        echo "✓ Server management backed up: server-management-$TIMESTAMP.tar.gz ($SIZE)"
    fi
fi

echo ""

# Clean up old backups
echo "Cleaning up old backups (keeping last $KEEP_BACKUPS)..."
cd "$BACKUP_DIR" || exit 0

for pattern in "app-registry-*.json" "apache2-config-*.tar.gz" "www-static-*.tar.gz" "pm2-dump-*.json" "server-management-*.tar.gz"; do
    COUNT=$(ls -1 $pattern 2>/dev/null | wc -l)
    if [ "$COUNT" -gt "$KEEP_BACKUPS" ]; then
        ls -t $pattern 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
    fi
done

echo "✓ Old backups cleaned"

echo ""

# Summary
echo "==========================================="
echo "Backup completed: $(date)"
echo "Backup location: $BACKUP_DIR"
echo "==========================================="
echo ""
echo "Recent backups:"
ls -lht "$BACKUP_DIR" | head -15 | tail -n +2 | awk '{print "  " $9 " - " $5 " (" $6 " " $7 ")"}'

echo ""

if [ "$UNCOMMITTED_FOUND" = true ]; then
    echo "⚠️  WARNING: Some projects have uncommitted changes!"
    echo "   Review and commit changes to preserve your work."
    echo ""
fi
