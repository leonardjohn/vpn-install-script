#!/usr/bin/env bash
# Offline regression tests for the jq extraction shape that broke Pre5.
set -Eeuo pipefail
command -v jq >/dev/null 2>&1 || { echo 'jq is required' >&2; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/release.json" <<'JSON'
{"assets":[{"name":"Xray-linux-64.zip","browser_download_url":"https://github.com/XTLS/Xray-core/releases/download/v26.10.31/Xray-linux-64.zip","digest":"sha256:e4bd9119f50ae7c41658b1abd0679ae06f98bd864a2907ff33f2f2cf7081b214"}]}
JSON
meta="$(jq -cer --arg name 'Xray-linux-64.zip' '[.assets[] | select(.name == $name) | {url: .browser_download_url, digest: .digest}] | if length == 1 then .[0] else error("Expected exactly one matching release asset") end' "$TMP/release.json")"
[[ "$(printf '%s' "$meta" | jq -r .url)" == https://github.com/XTLS/Xray-core/releases/download/v26.10.31/Xray-linux-64.zip ]]
[[ "$(printf '%s' "$meta" | jq -r .digest)" =~ ^sha256:[a-fA-F0-9]{64}$ ]]
if jq -cer --arg name 'missing.zip' '[.assets[] | select(.name == $name)] | if length == 1 then .[0] else error("Expected exactly one matching release asset") end' "$TMP/release.json" >/dev/null 2>&1; then
  echo 'FAIL: missing asset unexpectedly passed' >&2; exit 1
fi
echo 'PASS: one-line metadata extraction and missing-asset rejection'
