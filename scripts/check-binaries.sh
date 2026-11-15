#!/usr/bin/env bash
set -Eeuo pipefail
for b in /usr/local/bin/xray /usr/local/bin/sing-box; do
  [[ -x "$b" ]] || { echo "Missing executable: $b" >&2; exit 1; }
done
printf '========== XRAY VERSION ==========\n'
/usr/local/bin/xray version
printf '\n========== XRAY REALITY KEYGEN SELF-TEST ==========\n'
/usr/local/bin/xray x25519
printf '\n========== SING-BOX VERSION ==========\n'
/usr/local/bin/sing-box version
printf '\nBinary presence and CLI self-tests completed. This does not validate generated configs.\n'
