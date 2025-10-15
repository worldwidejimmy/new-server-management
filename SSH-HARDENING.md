# SSH Hardening and Fail2ban — kludgebot VPS

This document records the steps taken to harden SSH on the VPS and how to safely revert them.
Keep this file with your server management docs.

---

## Summary of actions performed

- Installed `fail2ban` and enabled a basic sshd jail (blocks repeated auth failures).
- Added an SSH hardening fragment to `/etc/ssh/sshd_config.d/90-hardening.conf` with the following settings:
  - `PasswordAuthentication no`
  - `ChallengeResponseAuthentication no`
  - `PermitRootLogin no`
- Reloaded `sshd` to apply the configuration.

These changes reduce the attack surface by blocking brute-force attempts and requiring key-based authentication.

---

## Safe pre-conditions (DO THIS FIRST)

1. Ensure you have at least one active SSH session (keep it open) while you make changes.
2. Test that your SSH key works from another client machine before disabling password auth:

```bash
# From your client (not the server):
ssh -i ~/.ssh/id_ed25519 ubuntu@vps-9108f4ba.vps.ovh.us
```

3. Make a backup copy of the current SSH config fragments (local server):

```bash
sudo cp -a /etc/ssh/sshd_config.d /etc/ssh/sshd_config.d.backup-$(date +%F-%H%M)
```

---

## Install Fail2ban (already performed)

Commands used to install and enable fail2ban:

```bash
sudo apt update
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
```

Create a basic local jail at `/etc/fail2ban/jail.d/ssh-local.conf` (example used):

```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600     ; seconds (1 hour)
findtime = 600     ; seconds (10 minutes)
```

Reload fail2ban:

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status
# or show jail status
sudo fail2ban-client status sshd
```

Notes:
- This will automatically ban IPs that fail authentication repeatedly.
- The `bantime` and `maxretry` settings can be tuned.

---

## SSH Hardening (applied)

The file created:

`/etc/ssh/sshd_config.d/90-hardening.conf`

Contents used:

```
# Hardening: disable password and challenge-response auth, disallow root login
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin no
# PubkeyAuthentication remains enabled (default)
```

Apply changes (done):

```bash
sudo systemctl reload sshd
```

Verify effective settings:

```bash
sudo sshd -T | egrep -i "passwordauthentication|permitrootlogin|challengeresponseauthentication|pubkeyauthentication"
# Expected output:
# passwordauthentication no
# permitrootlogin no
# challenger esponseauthentication no
# pubkeyauthentication yes
```

Important caution:
- Do not close your active SSH session until you verify that you can open a new SSH session (from a separate terminal or machine) using your SSH key.

---

## How to remove/revert these changes (quick rollback)

If anything goes wrong and you are locked out (or want to revert):

1. Restore the backup of SSH config fragments you created earlier (or remove the hardening file):

```bash
# Option A: remove the hardening fragment
sudo rm -f /etc/ssh/sshd_config.d/90-hardening.conf
sudo systemctl reload sshd

# Option B: restore backup directory (if you made one)
sudo rm -rf /etc/ssh/sshd_config.d
sudo mv /etc/ssh/sshd_config.d.backup-YYYY-MM-DD-HHMM /etc/ssh/sshd_config.d
sudo systemctl reload sshd
```

2. If you want to temporarily stop fail2ban (not recommended long-term):

```bash
sudo systemctl stop fail2ban
sudo systemctl disable fail2ban   # if you want it disabled permanently
```

3. If you need to revoke the emergency key or remove a key immediately (if laptop lost):

```bash
# Backup current authorized_keys then remove the offending key line(s)
cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak.$(date +%F-%H%M)
# Edit and delete the lines matching the lost-device comment/fingerprint
nano ~/.ssh/authorized_keys
# Or filter out by fingerprint (example: generate fingerprint of pub key you want to remove):
ssh-keygen -lf <(echo 'ssh-ed25519 AAAA... comment')
# Then remove matching line manually or with awk/sed
```

---

## Emergency recovery (if you get locked out)

If you are accidentally locked out and you have console access from your VPS provider (OVH Cloud control panel) you can use the provider's serial/console feature to log in and revert changes. If not, you must have a trusted user with SSH access who can revert changes.

---

## Optional: Cloudflare Tunnel for SSH (alternative approach)

If you want Cloudflare to protect SSH without exposing port 22, set up a Cloudflare Tunnel (`cloudflared`) and optionally protect it with Cloudflare Access. This means your server will not accept public SSH connections directly; instead the tunnel proxies through Cloudflare's network and can require identity checks.

High-level steps (not executed here):
- Install `cloudflared`
- `cloudflared tunnel create ssh-tunnel`
- Configure tunnel to route to `localhost:22`
- Create a DNS CNAME for `ssh.yourdomain.com` pointing to the tunnel
- (Optional) Configure Cloudflare Access policy to require login

---

## Notes & best practices

- Use passphrases on private keys, store encrypted copies in a password manager or GPG-encrypted archive.
- Consider using hardware keys (YubiKey) for production access.
- Keep at least one emergency key stored offline (encrypted USB or safe).
- Regularly rotate keys and audit `authorized_keys`.

---

Last updated: October 15, 2025
