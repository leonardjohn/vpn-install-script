#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CONFIG="$ROOT/config/server.env"
while (($#)); do
  case "$1" in
    --config) CONFIG=${2:?missing config path}; shift 2;;
    *) echo "Usage: $0 [--config PATH]" >&2; exit 2;;
  esac
done
[[ $EUID -eq 0 ]] || { echo 'Run with sudo/root.' >&2; exit 1; }
bash "$ROOT/scripts/validate-server-config.sh" "$CONFIG"
echo
echo '========== SERVER PREFLIGHT (READ ONLY) =========='
. /etc/os-release
printf 'OS: %s (%s)\n' "${PRETTY_NAME:-unknown}" "${VERSION_CODENAME:-unknown}"
[[ "${ID:-}" == debian && "${VERSION_ID:-}" == 12 ]] || { echo 'ERROR: this release targets Debian 12 only.' >&2; exit 1; }
printf 'Architecture: '; dpkg --print-architecture
[[ "$(dpkg --print-architecture)" == amd64 ]] || { echo 'ERROR: this release currently targets amd64.' >&2; exit 1; }
echo; echo '--- Package health ---'
dpkg --audit
apt-get check
for cmd in xray sing-box nginx; do
  if command -v "$cmd" >/dev/null 2>&1; then echo "CONFLICT: $cmd already exists at $(command -v "$cmd")"; else echo "OK: $cmd not installed"; fi
done
for svc in xray sing-box nginx; do
  state=$(systemctl is-active "$svc" 2>/dev/null || true)
  [[ "$state" == active ]] && echo "CONFLICT: $svc service is active" || echo "OK: $svc service not active"
done
echo; echo '--- Listening sockets ---'
ss -tulpen
 echo; echo '--- Firewall tooling ---'
for cmd in nft iptables ufw firewall-cmd; do command -v "$cmd" || true; done
 echo; echo '--- Time synchronization ---'
timedatectl status --no-pager || true
 echo; echo 'Preflight completed. No packages, services, firewall rules, or files were changed.'
