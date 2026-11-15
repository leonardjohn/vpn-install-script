#!/usr/bin/env bash
set -euo pipefail
CONFIG=${1:-"$(dirname "$0")/../config/server.env"}
[[ -f "$CONFIG" ]] || { echo "ERROR: config file not found: $CONFIG" >&2; exit 2; }
python3 "$(dirname "$0")/validate-server-config.py" "$CONFIG"
