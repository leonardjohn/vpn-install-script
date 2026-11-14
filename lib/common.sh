#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }
need_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die 'Run as root (sudo).'; }
backup_path() {
  local src="$1" dest="$2"
  if [[ -e "$src" ]]; then mkdir -p "$dest"; cp -a "$src" "$dest/"; fi
}
port_free() {
  local proto="$1" port="$2"
  if ss -H -lntu "( sport = :$port )" 2>/dev/null | grep -q .; then
    die "Port $port/$proto is already listening. No changes made."
  fi
}
valid_domain() { [[ "$1" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$ ]]; }
