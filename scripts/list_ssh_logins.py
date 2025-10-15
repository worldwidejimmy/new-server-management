#!/usr/bin/env python3
"""
list_ssh_logins.py

Scans /var/log/auth.log* and /var/log/secure* (including .gz) and `last -i`
for successful SSH authentication records (Accepted publickey/password),
then prints a summarized list of source IPs with counts, last-seen timestamp,
list_ssh_logins.py

Scans /var/log/auth.log* and /var/log/secure* (including .gz) and `last -i`
for successful SSH authentication records (Accepted publickey/password),
then prints a summarized list of source IPs with counts, last-seen timestamp,
methods seen and usernames.

Usage:
  ./list_ssh_logins.py

Writes nothing; prints to stdout. Designed to be run as a normal user with
# Lightweight SSH login summary script (no triple-quoted strings to avoid parser issues)
"""
import glob
import gzip
import re
import subprocess
from collections import defaultdict

LOG_PATTERNS = ['/var/log/auth.log*', '/var/log/secure*']
RE_ACCEPT = re.compile(r'Accepted\s+(?P<method>publickey|password)\s+for\s+(?P<user>\S+)\s+from\s+(?P<ip>\d+\.\d+\.\d+\.\d+)\s+port\s+(?P<port>\d+)(?:\s+ssh2:\s*(?P<keyinfo>.*))?', re.IGNORECASE)


def iter_log_files():
    seen = set()
    for pattern in LOG_PATTERNS:
        for path in sorted(glob.glob(pattern)):
            if path in seen:
                continue
            seen.add(path)
            yield path


def open_log(path):
    if path.endswith('.gz'):
        return gzip.open(path, 'rt', errors='ignore')
    return open(path, 'r', errors='ignore')


def parse_file_logs():
    records = []
    for path in iter_log_files():
        try:
            with open_log(path) as fh:
                for line in fh:
                    m = RE_ACCEPT.search(line)
                    if m:
                        g = m.groupdict()
                        ts_raw = line.split('sshd', 1)[0].strip() if 'sshd' in line else ''
                        records.append({
                            'ip': g.get('ip'),
                            'user': g.get('user'),
                            'method': g.get('method').lower(),
                            'port': g.get('port'),
                            'keyinfo': g.get('keyinfo') or '',
                            'ts_raw': ts_raw,
                            'source': path,
                        })
        except PermissionError:
            print(f"Warning: cannot read {path} (permission denied). Run with sudo to include this file.")
        except Exception as e:
            print(f"Warning: failed to read {path}: {e}")
    return records


def parse_last_i():
    last_info = defaultdict(lambda: {'count': 0, 'last_lines': []})
    try:
        proc = subprocess.run(['last', '-i'], capture_output=True, text=True)
        if proc.returncode != 0:
            return last_info
        lines = proc.stdout.strip().splitlines()
    except Exception:
        return last_info
    for ln in lines:
        parts = ln.split()
        if len(parts) >= 3:
            ip = parts[2]
            if re.match(r'^\d+\.\d+\.\d+\.\d+$', ip):
                last_info[ip]['count'] += 1
                last_info[ip]['last_lines'].append(ln)
    return last_info


def parse_journal():
    records = []
    try:
        proc = subprocess.run(['journalctl', '_COMM=sshd', '--no-pager', '-o', 'short-iso'], capture_output=True, text=True)
        if proc.returncode == 0:
            for line in proc.stdout.splitlines():
                m = RE_ACCEPT.search(line)
                if m:
                    g = m.groupdict()
                    ts_raw = line.split('sshd', 1)[0].strip()
                    records.append({
                        'ip': g.get('ip'),
                        'user': g.get('user'),
                        'method': g.get('method').lower(),
                        'port': g.get('port'),
                        'keyinfo': g.get('keyinfo') or '',
                        'ts_raw': ts_raw,
                        'source': 'journal',
                    })
    except Exception:
        pass
    return records


def summarize(records):
    stats = {}
    by_ip = defaultdict(list)
    for r in records:
        if not r.get('ip'):
            continue
        by_ip[r['ip']].append(r)
    for ip, recs in by_ip.items():
        methods = sorted({r['method'] for r in recs})
        users = sorted({r['user'] for r in recs})
        last_ts = ''
        for r in reversed(recs):
            if r.get('ts_raw'):
                last_ts = r['ts_raw']
                break
        stats[ip] = {
            'count': len(recs),
            'methods': methods,
            'users': users,
            'last_ts': last_ts,
        }
    return stats


def print_summary(stats, last_info):
    rows = []
    for ip, v in stats.items():
        last_seen = v['last_ts'] or (', '.join(last_info.get(ip, {}).get('last_lines', [])[:1]) if ip in last_info else '')
        rows.append((v['count'], ip, v['methods'], v['users'], last_seen))
    for ip, info in last_info.items():
        if ip not in stats:
            rows.append((info['count'], ip, [], [], ', '.join(info['last_lines'][:1])))
    rows.sort(reverse=True, key=lambda x: x[0])
    print("# Successful SSH logins summary (from auth logs and wtmp)")
    print(f"{'count':>5}  {'ip':<20}  {'methods':<20}  {'users':<20}  {'last_seen'}")
    print('-'*100)
    for count, ip, methods, users, last_seen in rows:
        methods_s = ','.join(methods) if methods else '-'
        users_s = ','.join(users) if users else '-'
        print(f"{count:5d}  {ip:<20}  {methods_s:<20}  {users_s:<20}  {last_seen}")


if __name__ == '__main__':
    recs = parse_file_logs()
    try:
        journal_recs = parse_journal()
        existing = {(r['ip'], r['user'], r['method'], r['port'], r.get('ts_raw','')) for r in recs}
        for jr in journal_recs:
            key = (jr.get('ip'), jr.get('user'), jr.get('method'), jr.get('port'), jr.get('ts_raw',''))
            if key not in existing:
                recs.append(jr)
    except Exception:
        pass
    last_info = parse_last_i()
    stats = summarize(recs)
    if not stats and not last_info:
        print('No successful SSH auth records found in logs (or insufficient permissions).')
    else:
        print_summary(stats, last_info)
