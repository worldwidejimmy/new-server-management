PM2 Guide

What we observed

- PM2 runs per-user. There were two PM2 daemons on the server:
  - A pm2 daemon owned by `ubuntu`, with PM2_HOME=/home/ubuntu/.pm2, managing the apps.
  - A pm2 daemon previously owned by `root` with PM2_HOME=/root/.pm2 (this had no apps and caused confusion).

What I did

1. Verified PM2 status for both users:
   - `pm2 status` as `ubuntu` showed apps `kludgebot-5070` and `talkingyam-prod`.
   - `pm2 status` as `root` was empty.
2. Confirmed there was a systemd unit `/etc/systemd/system/pm2-ubuntu.service` which is enabled but initially inactive.
3. Saved the pm2 process list for `ubuntu`:
   - `su - ubuntu -c 'pm2 save'` (wrote `/home/ubuntu/.pm2/dump.pm2`).
4. Stopped the old ubuntu pm2 daemon and started the systemd-managed pm2-ubuntu.service:
   - Because the existing daemon's PID file conflicted with systemd's checks, I ran:
     - `sudo -iu ubuntu pm2 kill` to stop the running daemon.
     - `sudo systemctl start pm2-ubuntu.service` to start PM2 under systemd.
   - Verified that `pm2-ubuntu.service` became active and PM2 resurrected the saved processes.
5. Cleaned up the root pm2 instance to avoid future confusion:
   - `sudo pm2 kill` (no processes found) and `sudo rm -rf /root/.pm2` to remove stale data.

Current state (as of this writeup)

- `pm2-ubuntu.service` exists, is enabled and active. It runs as `User=ubuntu` and uses `PM2_HOME=/home/ubuntu/.pm2`.
- `pm2 status` as `ubuntu` shows your two apps online.
- `pm2 status` as `root` is empty (no apps). The `/root/.pm2` directory has been removed.

Useful commands

# Check pm2 for ubuntu (recommended)
sudo -iu ubuntu pm2 status

# Save the current process list as ubuntu (so systemd's resurrect can restore it on boot)
su - ubuntu -c 'pm2 save'

# Start/stop the systemd-managed pm2 service
sudo systemctl start pm2-ubuntu.service
sudo systemctl stop pm2-ubuntu.service
sudo systemctl status --no-pager pm2-ubuntu.service

# View recent journal entries
sudo journalctl -u pm2-ubuntu.service --no-pager -n 200

# If you ever accidentally start pm2 as root and want to clean it up
sudo pm2 kill
sudo rm -rf /root/.pm2

Recommendations

- Manage PM2 as the `ubuntu` user (don't run `sudo pm2 ...` unless you intend to operate on root's PM2).
- Keep the systemd unit enabled (it's already enabled). Run `su - ubuntu -c 'pm2 save'` after making changes so `pm2 resurrect` restores them after reboot.
- Optionally add health checks or a small monitoring script that alerts when `pm2 status` shows a process down.

If you want, I can:
- Add a systemd timer that runs `pm2 save` periodically (e.g., daily) to ensure the dump is fresh.
- Recreate a small check script that verifies the apps respond on their HTTP ports after a restart.

---
Generated on: 2025-10-15

Next steps / TODOs

- [ ] Add a systemd timer to run `su - ubuntu -c 'pm2 save'` daily (helps keep `/home/ubuntu/.pm2/dump.pm2` fresh).
- [ ] Create a lightweight health-check script that probes configured HTTP ports and:
  - restarts individual pm2 processes if a health check fails, or
  - logs/alerts when an app is down.
- [ ] Add a periodic check (cron or systemd timer) to ensure `pm2-ubuntu.service` is active and restart it if it isn't.
- [ ] (Optional) Add a git-ignored helper that contains per-app health endpoints and expected status codes for the health-check script.

