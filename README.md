# VPN Deployment Toolkit — Debian 12 pre-release 3

This is the next engineering increment after pre2. It adds a safer configuration validator, a read-only server preflight, and local credential generation. It is **not yet a one-click VPN installer**: it does not install Xray/sing-box/Nginx, issue certificates, write service configurations, open firewalls, or publish subscriptions.

## Addressing model

- `SERVER_ADDRESS` is the address clients connect to: an owned DNS hostname or public IPv4.
- `REALITY_SNI` is always a manually chosen hostname. It is never inferred from the server IP.
- `REALITY_TARGET` remains `127.0.0.1:9443`, matching the VMISS local fallback architecture.
- In domain mode, ACME is planned for publicly trusted TLS certificates.
- In IPv4 mode, a self-signed IP-SAN certificate is planned for non-REALITY TLS services. Clients must explicitly trust it or accept the security trade-off of disabling certificate verification. The final installer must not silently enable insecure verification.

## Start locally

```bash
cp config/server.env.example config/server.env
# Edit server.env locally. Do not upload it or share generated secrets.
bash scripts/validate-server-config.sh config/server.env
```

For an IPv4-only example, start from `config/server-ipv4.env.example`. Replace the example IPv4 and manually choose a REALITY SNI hostname that is actually compatible with the configured REALITY target; the example hostname is not a recommendation.

## Preflight on the target Debian 12 server

Copy the toolkit to the VPS and run:

```bash
sudo bash scripts/server-preflight.sh --config config/server.env
```

This command is read-only. It checks Debian version, architecture, package health, existing services, listening ports, firewall tooling, and required configuration. It does not install packages or change firewall/service state.

## Generate per-server credentials

After validation, run locally or on the target server:

```bash
python3 scripts/generate-credentials.py --output /root/vpn-deploy-secrets
```

The script refuses to overwrite an existing output directory. It creates unique UUIDs/passwords/short ID material and restricts the directory and files to root-only permissions when run as root. REALITY X25519 keys are intentionally generated later by the pinned Xray binary so the final format exactly matches the deployed Xray version.

## Port plan (RackNerd profile)

- TCP 9444: VLESS REALITY
- TCP 9445: VLESS XHTTP
- TCP 2053: AnyTLS
- UDP 8444: Hysteria2
- UDP 8445: TUIC
- TCP+UDP 8388: Shadowsocks
- TCP 8446: Trojan TLS
- TCP 8447: VMess WebSocket TLS
- TCP 9446: subscription HTTPS (domain mode; IPv4 mode needs explicit certificate trust)
- TCP 9443 loopback only: local fallback

## Release status

This package has shell/Python syntax and configuration tests. It has not been validated against the real Xray/sing-box binaries or live clients. Do not deploy it as a production installer yet. See `docs/ROADMAP.md`.
