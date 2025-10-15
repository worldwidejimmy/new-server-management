#!/bin/bash

# Server status quick summary script
# Shows pm2 status, env check, backup listings, memory/disk usage, uptime, and network info

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/ubuntu/backups"

echo "========================================="
echo "Server Status Summary - $(date)"
echo "=========================================\n"

# Uptime and load
echo "Uptime and load:"
uptime
echo "\n"

# Memory usage
echo "Memory usage (free -h):"
free -h
echo "\n"

# Disk usage for / and /home
echo "Disk usage (df -h / /home):"
df -h / /home || df -h
echo "\n"

# PM2 status if pm2 exists
if command -v pm2 &> /dev/null; then
    echo "PM2 process list:"
    pm2 status || pm2 ls
else
    echo "pm2 not installed or not in PATH"
fi
echo "\n"

# Check env sync script
if [ -x "$SCRIPT_DIR/check-env-sync.sh" ]; then
    echo "Environment sync check:"
    "$SCRIPT_DIR/check-env-sync.sh" || true
else
    echo "check-env-sync.sh not found or not executable in $SCRIPT_DIR"
fi

echo "\n"
# Backups directory listing
if [ -d "$BACKUP_DIR" ]; then
    echo "Recent backups in $BACKUP_DIR:"
    ls -lht "$BACKUP_DIR" | head -n 20
else
    echo "$BACKUP_DIR does not exist"
fi

echo "\n"
# Recent syslog lines for errors
if [ -f /var/log/syslog ]; then
    echo "Recent syslog errors (last 200 lines matching -i error|fail|crit):"
    tail -n 500 /var/log/syslog | egrep -i "error|fail|crit|warn" | tail -n 200 || true
else
    echo "/var/log/syslog not found"
fi

# Network listening ports
echo "\nListening TCP ports (ss -tlnp):"
ss -tlnp | sed -n '1,200p'

echo "\n"
# Basic network check: resolve Google
echo "DNS resolve check:"
getent hosts google.com | head -n 1 || echo "DNS resolve failed"

echo "\n"
# Show last 50 auth log entries for SSH
if [ -f /var/log/auth.log ]; then
    echo "Recent SSH/auth events:" 
    tail -n 200 /var/log/auth.log | egrep "sshd|sudo|authentication" | tail -n 50 || true
else
    echo "/var/log/auth.log not found"
fi

echo "\n"
# Show current logged-in users
echo "Logged-in users:"
who -a || true

echo "\n========================================="
echo "End of server status"
echo "========================================="
