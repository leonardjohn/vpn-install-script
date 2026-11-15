#!/usr/bin/env bash
set -euo pipefail

CONFIG=${1:-"$(dirname "$0")/../config/server.env"}
if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: config file not found: $CONFIG" >&2
  exit 2
fi

# Read simple KEY=VALUE config without executing it as shell code.
declare -A C=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%$'\r'}
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  if [[ "$line" =~ ^([A-Z0-9_]+)=(.*)$ ]]; then
    key=${BASH_REMATCH[1]}; value=${BASH_REMATCH[2]}
    value=${value%\"}; value=${value#\"}
    value=${value%\'}; value=${value#\'}
    C[$key]=$value
  else
    echo "ERROR: invalid line in config: $line" >&2
    exit 2
  fi
done < "$CONFIG"
get(){ printf '%s' "${C[$1]-}"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }
need(){ [[ -n "$(get "$1")" ]] || fail "$1 must be set"; }

mode=$(get ADDRESS_MODE)
[[ "$mode" == domain || "$mode" == ipv4 ]] || fail "ADDRESS_MODE must be 'domain' or 'ipv4'"
need SERVER_ADDRESS
need REALITY_PORT
need REALITY_TARGET
need REALITY_SNI
need REALITY_FLOW
need REALITY_MIN_CLIENT_VER

if [[ ! "$(get REALITY_PORT)" =~ ^[0-9]{1,5}$ ]] || (( 10#$(get REALITY_PORT) < 1 || 10#$(get REALITY_PORT) > 65535 )); then
  fail "REALITY_PORT must be between 1 and 65535"
fi

# Validate hostname syntax (not DNS ownership or target compatibility).
host_re='^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(\.([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?))*\.?$'
[[ "$(get REALITY_SNI)" =~ $host_re ]] || fail "REALITY_SNI must be a hostname, not an IP address or URL"

if [[ "$mode" == domain ]]; then
  need BASE_DOMAIN
  need TLS_CERT_HOST
  need SUBSCRIPTION_HOST
  [[ "$(get SERVER_ADDRESS)" =~ $host_re ]] || fail "SERVER_ADDRESS must be a hostname in domain mode"
  [[ "$(get TLS_CERT_MODE)" == acme ]] || fail "domain mode currently requires TLS_CERT_MODE=acme"
  [[ "$(get TLS_CERT_HOST)" =~ $host_re ]] || fail "TLS_CERT_HOST must be a hostname"
else
  [[ -z "$(get BASE_DOMAIN)" ]] || fail "BASE_DOMAIN must be empty in ipv4 mode (avoid accidental domain assumptions)"
  [[ "$(get SERVER_ADDRESS)" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || fail "SERVER_ADDRESS must be an IPv4 address in ipv4 mode"
  IFS=. read -r a b c d <<< "$(get SERVER_ADDRESS)"
  for octet in "$a" "$b" "$c" "$d"; do (( 10#$octet <= 255 )) || fail "SERVER_ADDRESS contains an invalid IPv4 octet"; done
  [[ "$(get TLS_CERT_MODE)" == self_signed ]] || fail "ipv4 mode currently requires TLS_CERT_MODE=self_signed"
  [[ -z "$(get TLS_CERT_HOST)" ]] || fail "TLS_CERT_HOST should be empty in ipv4 mode; certificate will use the IP SAN"
  [[ -z "$(get SUBSCRIPTION_HOST)" ]] || fail "SUBSCRIPTION_HOST should be empty in ipv4 mode unless a separate hostname is deliberately configured"
fi

# Target accepts host:port. This checks syntax only, not whether the target serves TLS.
[[ "$(get REALITY_TARGET)" =~ ^[^[:space:]:]+:[0-9]{1,5}$ ]] || fail "REALITY_TARGET must use host:port syntax"
target=$(get REALITY_TARGET)
port=${target##*:}
(( 10#$port >= 1 && 10#$port <= 65535 )) || fail "REALITY_TARGET port is out of range"

cat <<OUT
Configuration syntax: PASS
Address mode: $mode
Client connection address: $(get SERVER_ADDRESS)
REALITY listener: $(get REALITY_PORT)
REALITY target: $(get REALITY_TARGET)
REALITY SNI: $(get REALITY_SNI)
TLS certificate mode: $(get TLS_CERT_MODE)

NOTE: This validator cannot prove that REALITY_SNI is served by REALITY_TARGET,
that DNS points to this VPS, or that an ACME/self-signed certificate works.
Those checks belong in the deployment and external validation stages.
OUT
