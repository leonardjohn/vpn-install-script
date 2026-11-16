#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/scripts/install-pinned-binaries.sh"

for cmd in jq grep; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "SKIP/FAIL: required test utility missing: $cmd" >&2
    exit 1
  }
done

echo "========== VERIFY PRODUCTION INSTALLER IMPLEMENTATION =========="
grep -Fq 'meta="$(jq -cer --arg name "$asset"' "$INSTALLER"
if grep -Fq '| head -n1' "$INSTALLER"; then
  echo "FAIL: production installer still truncates jq JSON with head -n1" >&2
  exit 1
fi
grep -Fq 'Expected exactly one release asset' "$INSTALLER"
grep -Fq 'XRAY_PLACED=1' "$INSTALLER"
grep -Fq 'SINGBOX_PLACED=1' "$INSTALLER"
grep -Fq '(( XRAY_PLACED == 1 )) && rm -f /usr/local/bin/xray' "$INSTALLER"
echo "PASS: production installer uses compact jq output, enforces one asset, and contains rollback guards"

echo
echo "========== TEST COMPACT ASSET EXTRACTION =========="
fixture="$(mktemp)"
trap 'rm -f "$fixture"' EXIT
cat > "$fixture" <<'JSON'
{
  "assets": [
    {
      "name": "Xray-linux-64.zip",
      "browser_download_url": "https://github.com/XTLS/Xray-core/releases/download/v-test/Xray-linux-64.zip",
      "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ]
}
JSON

count="$(jq --arg name "Xray-linux-64.zip" '[.assets[] | select(.name == $name)] | length' "$fixture")"
[[ "$count" == "1" ]]
meta="$(jq -cer --arg name "Xray-linux-64.zip" \
  '.assets[] | select(.name == $name) | {url: .browser_download_url, digest: .digest}' \
  "$fixture")"
[[ "$(printf '%s' "$meta" | wc -l)" -eq 0 ]]
[[ "$(printf '%s' "$meta" | jq -r '.url')" == "https://github.com/XTLS/Xray-core/releases/download/v-test/Xray-linux-64.zip" ]]
echo "PASS: compact extraction produces one valid JSON object"

echo
echo "========== TEST MISSING AND DUPLICATE ASSETS =========="
if jq -cer --arg name "missing.zip" \
  '.assets[] | select(.name == $name) | {url: .browser_download_url, digest: .digest}' \
  "$fixture" >/dev/null 2>&1; then
  echo "FAIL: missing asset was accepted" >&2
  exit 1
fi

jq '.assets += [.assets[0]]' "$fixture" > "${fixture}.duplicate"
count="$(jq --arg name "Xray-linux-64.zip" '[.assets[] | select(.name == $name)] | length' "${fixture}.duplicate")"
rm -f "${fixture}.duplicate"
[[ "$count" == "2" ]]
echo "PASS: missing and duplicate asset conditions are detected"
