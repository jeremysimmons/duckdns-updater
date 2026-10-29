#!/usr/bin/env bash
set -euo pipefail
CONFIG=/etc/duckdns/duckdns.conf
[[ -r "$CONFIG" ]] || { echo 'ERROR: Missing /etc/duckdns/duckdns.conf' >&2; exit 1; }
# Shell source only a root-owned, non-world-readable config created by installer.
# shellcheck disable=SC1090
source "$CONFIG"
: "${DOMAINS:?DOMAINS missing}"
: "${TOKEN:?TOKEN missing}"
response=$(curl --fail --silent --show-error --max-time 30 --get \
  --data-urlencode "domains=$DOMAINS" --data-urlencode "token=$TOKEN" \
  'https://www.duckdns.org/update') || { echo 'ERROR: DuckDNS HTTPS request failed' >&2; exit 1; }
if [[ "$response" != OK && "$response" != OK$'\n'* ]]; then
  echo 'ERROR: DuckDNS rejected update' >&2
  exit 1
fi
echo "OK: $DOMAINS"
