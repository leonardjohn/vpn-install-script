#!/usr/bin/env bash
set -euo pipefail
DIR="${1:?Usage: validate-rendered-configs.sh STAGING_DIR}"
[[ -f "$DIR/xray-config.json" && -f "$DIR/sing-box-config.json" ]] || { echo "Missing staged configs" >&2; exit 1; }
python3 - "$DIR" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1])
for f in ('xray-config.json','sing-box-config.json'):
    json.loads((p/f).read_text())
    print(f'{f}: JSON syntax PASS')
PY
if command -v xray >/dev/null 2>&1; then
  xray run -test -config "$DIR/xray-config.json"
else
  echo "SKIP: xray binary not installed; native validation not performed"
fi
if command -v sing-box >/dev/null 2>&1; then
  sing-box check -c "$DIR/sing-box-config.json"
else
  echo "SKIP: sing-box binary not installed; native validation not performed"
fi
