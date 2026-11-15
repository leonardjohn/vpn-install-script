#!/usr/bin/env bash
set -Eeuo pipefail

# Installs only the pinned Xray and sing-box executables. Does not create
# configs, users, services, firewall rules, certificates, or start daemons.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT_DIR/locks/binaries.env"
[[ $EUID -eq 0 ]] || { echo 'Run as root: sudo bash scripts/install-pinned-binaries.sh' >&2; exit 1; }
[[ -r /etc/os-release ]] || { echo 'Cannot identify OS' >&2; exit 1; }
. /etc/os-release
[[ "${ID:-}" == debian && "${VERSION_ID:-}" == 12 ]] || { echo 'This release supports Debian 12 only.' >&2; exit 1; }
[[ "$(dpkg --print-architecture)" == amd64 ]] || { echo 'This release supports amd64 only.' >&2; exit 1; }
[[ -f "$LOCK" ]] || { echo "Missing lock file: $LOCK" >&2; exit 1; }
# shellcheck disable=SC1090
. "$LOCK"

for bin in curl jq unzip tar sha256sum install file find; do
  command -v "$bin" >/dev/null || { echo "Missing required utility: $bin" >&2; exit 1; }
done

for bin in xray sing-box; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "REFUSING to overwrite existing $bin at $(command -v "$bin"). Inspect it first." >&2
    exit 1
  fi
done

TMP="$(mktemp -d /var/tmp/vpn-deploy-binaries.XXXXXX)"
chmod 700 "$TMP"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT

fetch_release_asset(){
  local repo="$1" tag="$2" asset="$3" out="$4" api="$TMP/release.json" meta url digest
  echo "Fetching release metadata: $repo $tag"
  curl --fail --silent --show-error --location \
    --retry 3 --retry-delay 2 \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "https://api.github.com/repos/$repo/releases/tags/$tag" -o "$api"
  meta="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | {url: .browser_download_url, digest: .digest}' "$api" | head -n1)"
  url="$(printf '%s' "$meta" | jq -er '.url')"
  digest="$(printf '%s' "$meta" | jq -er '.digest // empty')"
  [[ "$url" == https://github.com/* ]] || { echo "Unexpected asset URL for $asset" >&2; exit 1; }
  [[ "$digest" =~ ^sha256:[a-fA-F0-9]{64}$ ]] || {
    echo "GitHub release API did not provide a SHA-256 digest for $asset. Refusing unverified download." >&2
    exit 1
  }
  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 "$url" -o "$out"
  local expected="${digest#sha256:}" actual
  actual="$(sha256sum "$out" | awk '{print $1}')"
  [[ "${actual,,}" == "${expected,,}" ]] || { echo "SHA-256 mismatch for $asset" >&2; exit 1; }
  echo "Verified $asset SHA-256: $actual"
}

XRAY_ARCHIVE="$TMP/$XRAY_ASSET"
SB_ARCHIVE="$TMP/$SINGBOX_ASSET"
fetch_release_asset "$XRAY_REPO" "$XRAY_TAG" "$XRAY_ASSET" "$XRAY_ARCHIVE"
fetch_release_asset "$SINGBOX_REPO" "$SINGBOX_TAG" "$SINGBOX_ASSET" "$SB_ARCHIVE"

mkdir "$TMP/xray" "$TMP/singbox"
unzip -q "$XRAY_ARCHIVE" -d "$TMP/xray"
tar -xzf "$SB_ARCHIVE" -C "$TMP/singbox"
XRAY_BIN="$(find "$TMP/xray" -type f -name xray -perm /111 -print -quit)"
SB_BIN="$(find "$TMP/singbox" -type f -name sing-box -perm /111 -print -quit)"
[[ -n "$XRAY_BIN" && -n "$SB_BIN" ]] || { echo 'Expected executable not found in verified archives' >&2; exit 1; }

# Verify executable architecture before placing anything in PATH.
file "$XRAY_BIN" | grep -q 'ELF 64-bit.*x86-64' || { echo 'Xray binary architecture mismatch' >&2; exit 1; }
file "$SB_BIN" | grep -q 'ELF 64-bit.*x86-64' || { echo 'sing-box binary architecture mismatch' >&2; exit 1; }

install -o root -g root -m 0755 "$XRAY_BIN" /usr/local/bin/xray
install -o root -g root -m 0755 "$SB_BIN" /usr/local/bin/sing-box

printf '\n========== INSTALLED BINARY VERSIONS ==========\n'
/usr/local/bin/xray version
/usr/local/bin/sing-box version
printf '\nBinaries installed. No services or network listeners were created or started.\n'
