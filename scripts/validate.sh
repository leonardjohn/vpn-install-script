#!/usr/bin/env bash
set -Eeuo pipefail
fail=0
if command -v xray >/dev/null 2>&1; then xray run -test -config /usr/local/etc/xray/config.json && echo '[OK] Xray config' || fail=1; fi
if command -v sing-box >/dev/null 2>&1; then sing-box check -c /etc/sing-box/config.json && echo '[OK] sing-box config' || fail=1; fi
if command -v nginx >/dev/null 2>&1; then nginx -t && echo '[OK] Nginx config' || fail=1; fi
for s in xray sing-box nginx; do systemctl is-active --quiet "$s" && echo "[OK] $s active" || { echo "[FAIL] $s inactive"; fail=1; }; done
exit "$fail"
