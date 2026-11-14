#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run with sudo/root.' >&2; exit 1; }
FILE=/etc/vpn-deploy/secrets/subscription-urls.txt
[[ -r "$FILE" ]] || { echo 'Subscription URL file not found; installation may be incomplete.' >&2; exit 1; }
cat "$FILE"
