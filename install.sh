#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"
CONFIG=''
while (($#)); do
  case "$1" in
    --config) [[ $# -ge 2 ]] || die '--config requires a file'; CONFIG="$2"; shift 2;;
    -h|--help) echo 'Usage: sudo bash install.sh --config config/server.env'; exit 0;;
    *) die "Unknown argument: $1";;
  esac
done
need_root
[[ -n "$CONFIG" ]] || die 'Specify --config config/server.env'
[[ -f "$CONFIG" ]] || die "Configuration not found: $CONFIG"
CONFIG="$(realpath "$CONFIG")"
[[ "$(. /etc/os-release; echo "$ID:$VERSION_ID")" == 'debian:12' ]] || die 'Only Debian 12 is supported.'
[[ "$(dpkg --print-architecture)" == 'amd64' ]] || die 'Only amd64 is supported.'
[[ ! -e /etc/vpn-deploy/state.json ]] || die 'Toolkit state already exists; upgrades are not supported by this release.'
for bin in xray sing-box nginx apache2; do command -v "$bin" >/dev/null 2>&1 && die "Detected existing $bin binary. Refusing to overwrite it."; done
for path in /usr/local/etc/xray/config.json /etc/sing-box/config.json /etc/nginx/sites-available/vpn-subscription /etc/ssl/vpn /etc/vpn-deploy; do [[ ! -e "$path" ]] || die "Existing path detected: $path. Refusing to overwrite."; done
for svc in xray sing-box nginx apache2; do
  if systemctl list-unit-files "${svc}.service" --no-legend 2>/dev/null | grep -q "${svc}.service"; then
    die "Detected existing ${svc} service. Refusing to overwrite it."
  fi
done
set -a
# shellcheck disable=SC1090
source "$CONFIG"
set +a
required=(SERVER_ID SERVER_IPV4 BASE_DOMAIN REALITY_HOST XHTTP_HOST ANYTLS_HOST HY2_HOST TUIC_HOST SS_HOST TROJAN_HOST VMESS_HOST WEB_HOST SUB_HOST XRAY_VERSION SINGBOX_VERSION ACME_EMAIL REALITY_DEST REALITY_SNI XHTTP_PATH PORT_REALITY PORT_XHTTP PORT_ANYTLS PORT_HY2 PORT_TUIC PORT_SS PORT_TROJAN PORT_VMESS PORT_SUB PORT_FALLBACK)
for k in "${required[@]}"; do [[ -n "${!k:-}" ]] || die "Missing required value: $k"; done
[[ "$ACME_EMAIL" == *@*.* ]] || die 'Set a valid ACME_EMAIL before installation.'
[[ "$SERVER_IPV4" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die 'SERVER_IPV4 is not an IPv4 address.'
for h in "$REALITY_HOST" "$XHTTP_HOST" "$ANYTLS_HOST" "$HY2_HOST" "$TUIC_HOST" "$SS_HOST" "$TROJAN_HOST" "$VMESS_HOST" "$WEB_HOST" "$SUB_HOST"; do valid_domain "$h" || die "Invalid hostname: $h"; done
valid_domain "$REALITY_SNI" || die 'REALITY_SNI must be a valid DNS hostname.'
[[ "$REALITY_DEST" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]] || die 'REALITY_DEST must be hostname:port.'
DEST_HOST="${REALITY_DEST%:*}"; DEST_PORT="${REALITY_DEST##*:}"
((DEST_PORT > 0 && DEST_PORT < 65536)) || die 'Invalid REALITY_DEST port.'
# Ensure ports are numeric and unique.
ports=(80 "$PORT_REALITY" "$PORT_XHTTP" "$PORT_ANYTLS" "$PORT_HY2" "$PORT_TUIC" "$PORT_SS" "$PORT_TROJAN" "$PORT_VMESS" "$PORT_SUB" "$PORT_FALLBACK")
for p in "${ports[@]}"; do [[ "$p" =~ ^[0-9]+$ ]] && ((p > 0 && p < 65536)) || die "Invalid port: $p"; done
for ((i=0;i<${#ports[@]};i++)); do for ((j=i+1;j<${#ports[@]};j++)); do [[ "${ports[i]}" != "${ports[j]}" ]] || die "Duplicate port: ${ports[i]}"; done; done
# Preflight port conflicts. 9443 is checked on loopback as well.
for p in 80 "$PORT_REALITY" "$PORT_XHTTP" "$PORT_ANYTLS" "$PORT_HY2" "$PORT_TUIC" "$PORT_SS" "$PORT_TROJAN" "$PORT_VMESS" "$PORT_SUB" "$PORT_FALLBACK"; do port_free tcp "$p"; done
# All ten DNS names must resolve to the intended public IPv4 before ACME issuance.
for h in "$REALITY_HOST" "$XHTTP_HOST" "$ANYTLS_HOST" "$HY2_HOST" "$TUIC_HOST" "$SS_HOST" "$TROJAN_HOST" "$VMESS_HOST" "$WEB_HOST" "$SUB_HOST"; do
  got="$(getent ahostsv4 "$h" | awk 'NR==1{print $1}')"
  [[ "$got" == "$SERVER_IPV4" ]] || die "$h resolves to '${got:-nothing}', expected $SERVER_IPV4. Fix DNS first."
done
timeout 8 bash -c ":</dev/tcp/${DEST_HOST}/${DEST_PORT}" >/dev/null 2>&1 || die "REALITY destination $REALITY_DEST is not reachable over TCP from this VPS. Choose and verify another target."
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP="/var/backups/vpn-deploy/$STAMP"
mkdir -p "$BACKUP" /etc/vpn-deploy
chmod 700 /etc/vpn-deploy
cp -a "$CONFIG" "$BACKUP/server.env"
cp -a "$HERE" "$BACKUP/toolkit"
log "Preflight passed. Backup created at $BACKUP"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl unzip jq python3 python3-yaml nginx openssl socat cron

log "Installing Xray $XRAY_VERSION via the official XTLS installer."
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u xray --version "v${XRAY_VERSION}"
log "Installing sing-box $SINGBOX_VERSION from its official release archive."
ARCHIVE="/tmp/sing-box-${SINGBOX_VERSION}-linux-amd64.tar.gz"
curl -fL --retry 3 "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-amd64.tar.gz" -o "$ARCHIVE"
TMP="$(mktemp -d)"
tar -xzf "$ARCHIVE" -C "$TMP"
install -m 0755 "$TMP/sing-box-${SINGBOX_VERSION}-linux-amd64/sing-box" /usr/local/bin/sing-box
rm -rf "$TMP" "$ARCHIVE"
if ! id sing-box >/dev/null 2>&1; then useradd --system --no-create-home --shell /usr/sbin/nologin sing-box; fi

# Shared read-only certificate group for Xray, sing-box and Nginx.
getent group vpncert >/dev/null || groupadd --system vpncert
usermod -aG vpncert xray
usermod -aG vpncert sing-box
usermod -aG vpncert www-data
install -d -o root -g sing-box -m 0750 /etc/sing-box
install -d -o sing-box -g sing-box -m 0750 /var/log/sing-box
install -d -o root -g vpncert -m 0750 /etc/ssl/vpn/shared
install -d -o root -g www-data -m 0750 /var/www/acme/.well-known/acme-challenge /var/lib/vpn-subscription

cat > /etc/systemd/system/sing-box.service <<'UNIT'
[Unit]
Description=sing-box service
After=network-online.target
Wants=network-online.target
[Service]
User=sing-box
Group=sing-box
SupplementaryGroups=vpncert
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/sing-box
[Install]
WantedBy=multi-user.target
UNIT
mkdir -p /etc/systemd/system/xray.service.d
cat > /etc/systemd/system/xray.service.d/vpncert.conf <<'UNIT'
[Service]
SupplementaryGroups=vpncert
UNIT

# Temporary HTTP-only Nginx site for ACME HTTP-01 validation.
cat > /etc/nginx/sites-available/vpn-subscription <<NGINX
server {
    listen 80;
    server_name ${REALITY_HOST} ${XHTTP_HOST} ${ANYTLS_HOST} ${HY2_HOST} ${TUIC_HOST} ${SS_HOST} ${TROJAN_HOST} ${VMESS_HOST} ${WEB_HOST} ${SUB_HOST};
    location ^~ /.well-known/acme-challenge/ { root /var/www/acme; default_type text/plain; }
    location / { return 404; }
}
NGINX
ln -s /etc/nginx/sites-available/vpn-subscription /etc/nginx/sites-enabled/vpn-subscription
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl restart nginx

log 'Installing acme.sh and issuing the SAN certificate using HTTP-01.'
curl -fsSL https://get.acme.sh | sh -s email="$ACME_EMAIL"
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue --keylength ec-256 --webroot /var/www/acme \
  -d "$REALITY_HOST" -d "$XHTTP_HOST" -d "$ANYTLS_HOST" -d "$HY2_HOST" -d "$TUIC_HOST" \
  -d "$SS_HOST" -d "$TROJAN_HOST" -d "$VMESS_HOST" -d "$WEB_HOST" -d "$SUB_HOST"

# Generate per-server credentials and REALITY keys. Never print the values.
XRAY_KEYS="$(/usr/local/bin/xray x25519)"
REALITY_PRIVATE="$(printf '%s\n' "$XRAY_KEYS" | awk -F': *' '/^(PrivateKey|Private key):/{print $2;exit}')"
REALITY_PUBLIC="$(printf '%s\n' "$XRAY_KEYS" | awk -F': *' '/^(PublicKey|Public key|Password)/{print $2;exit}')"
[[ -n "$REALITY_PRIVATE" && -n "$REALITY_PUBLIC" ]] || die 'Could not parse Xray x25519 output. Stop and inspect `xray x25519` manually; do not share private output.'
install -d -o root -g root -m 0700 /etc/vpn-deploy/secrets
export VPN_DEPLOY_CONFIG="$CONFIG"
python3 "$HERE/scripts/generate.py"
python3 - "$REALITY_PRIVATE" "$REALITY_PUBLIC" <<'PY'
import json,sys
p='/etc/vpn-deploy/secrets/credentials.json'
d=json.load(open(p)); d['reality_private']=sys.argv[1]; d['reality_public']=sys.argv[2]
open(p,'w').write(json.dumps(d,indent=2)+'\n')
PY
chmod 600 /etc/vpn-deploy/secrets/credentials.json /etc/vpn-deploy/secrets/subscription-token.txt

# Install certificate with restricted group-readable private key.
cat > /usr/local/sbin/vpn-cert-deploy <<'HOOK'
#!/usr/bin/env bash
set -Eeuo pipefail
for f in /etc/ssl/vpn/shared/fullchain.pem /etc/ssl/vpn/shared/private.key; do [[ -s "$f" ]] || exit 1; done
chown root:vpncert /etc/ssl/vpn/shared/private.key /etc/ssl/vpn/shared/fullchain.pem
chmod 640 /etc/ssl/vpn/shared/private.key /etc/ssl/vpn/shared/fullchain.pem
if systemctl is-active --quiet xray; then systemctl restart xray; fi
if systemctl is-active --quiet sing-box; then systemctl restart sing-box; fi
if systemctl is-active --quiet nginx; then nginx -t && systemctl reload nginx; fi
HOOK
chmod 750 /usr/local/sbin/vpn-cert-deploy
/root/.acme.sh/acme.sh --install-cert -d "$REALITY_HOST" \
  --key-file /etc/ssl/vpn/shared/private.key \
  --fullchain-file /etc/ssl/vpn/shared/fullchain.pem \
  --reloadcmd /usr/local/sbin/vpn-cert-deploy
chown root:vpncert /etc/ssl/vpn/shared/private.key /etc/ssl/vpn/shared/fullchain.pem
chmod 640 /etc/ssl/vpn/shared/private.key /etc/ssl/vpn/shared/fullchain.pem

# Render configurations and profiles; enforce service-readable, non-world-readable files.
python3 "$HERE/scripts/build_configs.py" "$CONFIG"
chown root:xray /usr/local/etc/xray/config.json; chmod 640 /usr/local/etc/xray/config.json
chown root:sing-box /etc/sing-box/config.json; chmod 640 /etc/sing-box/config.json
chown -R root:www-data /var/lib/vpn-subscription; chmod 750 /var/lib/vpn-subscription; chmod 640 /var/lib/vpn-subscription/*
chown root:root /etc/nginx/sites-available/vpn-subscription; chmod 640 /etc/nginx/sites-available/vpn-subscription

# Validate every configuration before enabling VPN daemons.
/usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
/usr/local/bin/sing-box check -c /etc/sing-box/config.json
nginx -t
systemctl daemon-reload
systemctl enable xray sing-box
systemctl restart xray sing-box
systemctl reload nginx

install -m 0600 "$CONFIG" /etc/vpn-deploy/server.env
cat > /etc/vpn-deploy/state.json <<STATE
{"version":"0.1.0-pre1","server_id":"$SERVER_ID","installed_at_utc":"$(date -u +%FT%TZ)","backup":"$BACKUP"}
STATE
chmod 600 /etc/vpn-deploy/state.json
log 'Installation completed. Validate service health and test client imports before production use.'
log "Backup retained at: $BACKUP"
