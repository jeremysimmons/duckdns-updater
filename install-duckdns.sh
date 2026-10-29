#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo 'Run as root: sudo ./install-duckdns.sh domain1[,domain2]' >&2; exit 1; fi
if [[ $# -ne 1 ]]; then echo 'Usage: sudo ./install-duckdns.sh domain1[,domain2]' >&2; exit 1; fi
command -v systemctl >/dev/null || { echo 'systemd is required' >&2; exit 1; }
command -v curl >/dev/null || { echo 'Install curl first' >&2; exit 1; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f "$script_dir/duckdns-update.sh" ]] || { echo 'Missing duckdns-update.sh beside installer' >&2; exit 1; }
domains=${1//.duckdns.org/}
[[ $domains =~ ^[a-zA-Z0-9-]+(,[a-zA-Z0-9-]+)*$ ]] || { echo 'Invalid domain list' >&2; exit 1; }
read -r -s -p 'DuckDNS token: ' token </dev/tty; echo
[[ -n $token ]] || { echo 'Token cannot be empty' >&2; exit 1; }
umask 077
install -d -m 700 /etc/duckdns
install -m 700 "$script_dir/duckdns-update.sh" /usr/local/sbin/duckdns-update
# printf %q prevents arbitrary tokens from being interpreted as shell code when sourced.
{ printf 'DOMAINS=%q\n' "$domains"; printf 'TOKEN=%q\n' "$token"; } > /etc/duckdns/duckdns.conf
chmod 600 /etc/duckdns/duckdns.conf
cat > /etc/systemd/system/duckdns.service <<'SERVICE'
[Unit]
Description=Update DuckDNS dynamic DNS
Wants=network-online.target
After=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/duckdns-update
User=root
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
SERVICE
cat > /etc/systemd/system/duckdns.timer <<'TIMER'
[Unit]
Description=Update DuckDNS every five minutes
[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true
Unit=duckdns.service
[Install]
WantedBy=timers.target
TIMER
systemctl daemon-reload
systemctl enable --now duckdns.timer
systemctl start duckdns.service
echo "Installed: $domains. Check: systemctl status duckdns.timer; journalctl -u duckdns.service -n 20"
