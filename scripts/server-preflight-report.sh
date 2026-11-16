#!/usr/bin/env bash
# Read-only server preflight report. Does not install packages or change settings.
set -u

section(){ printf '\n========== %s ==========\n' "$1"; }
warn(){ printf 'WARNING: %s\n' "$1"; }
ok(){ printf 'OK: %s\n' "$1"; }

section 'SERVER IDENTITY'
printf 'Hostname: '; hostname 2>/dev/null || true
if [[ -r /etc/os-release ]]; then . /etc/os-release; printf 'OS: %s\n' "${PRETTY_NAME:-unknown}"; printf 'Version: %s\n' "${VERSION_ID:-unknown}"; else warn '/etc/os-release unavailable'; fi
printf 'Architecture: '; dpkg --print-architecture 2>/dev/null || uname -m
printf 'Kernel: '; uname -r

section 'REQUIRED UTILITIES'
missing=0
for c in curl jq unzip tar sha256sum file find install awk grep sed; do
  if command -v "$c" >/dev/null 2>&1; then printf 'Available: %s\n' "$c"; else printf 'Missing: %s\n' "$c"; missing=1; fi
done
(( missing == 0 )) && ok 'All binary-installer utilities are available' || warn 'Install missing utilities before running the binary installer'

section 'EXISTING VPN BINARIES'
for c in xray sing-box; do
  path="$(command -v "$c" 2>/dev/null || true)"
  if [[ -n "$path" ]]; then
    printf 'FOUND: %s at %s\n' "$c" "$path"
    "$path" version 2>&1 | sed -n '1,5p' || warn "Could not read $c version"
  else
    printf 'Not found in PATH: %s\n' "$c"
  fi
done
for p in /usr/local/bin/xray /usr/local/bin/sing-box; do [[ ! -e "$p" ]] || printf 'Existing target path: %s\n' "$p"; done

section 'SYSTEMD SERVICE UNITS'
for s in xray sing-box nginx; do
  if systemctl list-unit-files "${s}.service" --no-legend 2>/dev/null | grep -q "^${s}\.service"; then
    printf '%s: unit present; active=' "$s"; systemctl is-active "$s" 2>/dev/null || true
  else printf '%s: no unit file found\n' "$s"; fi
done

section 'DISK SPACE'
df -h / /var/tmp 2>/dev/null || true

section 'LISTENING TCP/UDP PORTS'
if command -v ss >/dev/null 2>&1; then ss -lntup 2>/dev/null || true; else warn 'ss command unavailable'; fi

section 'SSH AUTHENTICATION (EFFECTIVE SETTINGS)'
if command -v sshd >/dev/null 2>&1; then
  sshd -T 2>/dev/null | grep -E '^(permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|authenticationmethods) ' || warn 'Could not obtain effective sshd settings'
else warn 'sshd not found'; fi

section 'SUMMARY'
printf 'This report is read-only. It does not install, remove, enable, disable, restart, or reconfigure anything.\n'
