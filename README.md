# VPN Deployment Toolkit — Debian 12 pre-release 4

Pre4 adds the first Xray/sing-box configuration renderer and a REALITY X25519 key helper. It is still a **configuration-engine milestone, not a one-click production installer**. It does not install binaries, issue certificates, install systemd units, open provider firewalls, or publish subscription files.

## Addressing model

- `SERVER_ADDRESS`: client connection address (owned DNS name or public IPv4).
- `REALITY_SNI`: manually supplied hostname; never inferred from the server IP.
- `REALITY_TARGET`: local TLS fallback, default `127.0.0.1:9443`, matching the VMISS design supplied by the user.
- Domain mode expects a publicly trusted ACME certificate covering the chosen TLS hostnames.
- IPv4 mode expects a self-signed certificate whose SAN contains the selected REALITY SNI and server IP. Client trust requirements must be handled explicitly; the toolkit never silently enables insecure verification.

## Files added in pre4

- `scripts/generate-reality-keys.py`: invokes the installed Xray binary's `xray x25519` command, parses the current `PrivateKey` and `Password (PublicKey)`/`Password` formats, and safely adds them to the existing credentials JSON. It refuses to overwrite existing REALITY keys.
- `scripts/render-configs.py`: renders four Xray inbounds (REALITY, XHTTP, Trojan TLS, VMess WS TLS), four sing-box inbounds (AnyTLS, Hysteria2, TUIC, Shadowsocks), and a loopback Nginx REALITY fallback server snippet. It writes only to a new staging directory.
- `scripts/validate-rendered-configs.sh`: checks JSON syntax and runs native Xray/sing-box validators if the binaries are installed.

## Local / staging workflow

```bash
cp config/server.env.example config/server.env
# Edit server.env locally. Keep it private.
bash scripts/validate-server-config.sh config/server.env
sudo python3 scripts/generate-credentials.py --output /root/vpn-deploy-secrets
sudo python3 scripts/generate-reality-keys.py --credentials /root/vpn-deploy-secrets/credentials.json --xray /usr/local/bin/xray
sudo python3 scripts/render-configs.py \
  --config config/server.env \
  --credentials /root/vpn-deploy-secrets/credentials.json \
  --output /root/vpn-deploy-staging
sudo bash scripts/validate-rendered-configs.sh /root/vpn-deploy-staging
```

The `generate-credentials.py` output directory must not already exist. The renderer also refuses to overwrite an existing output directory. Keep both directories root-only. Do not paste, upload, commit or send credentials files.

For IPv4-only deployment, copy `config/server-ipv4.env.example`, set `SERVER_ADDRESS` to the server's public IPv4 and manually set `REALITY_SNI` to a hostname that is actually compatible with the fallback target/certificate. The sample `www.example.com` is a placeholder, not a recommendation.

## Port profile

- TCP 9444: VLESS REALITY
- TCP 9445: VLESS XHTTP
- TCP 2053: AnyTLS
- UDP 8444: Hysteria2
- UDP 8445: TUIC
- TCP+UDP 8388: Shadowsocks
- TCP 8446: Trojan TLS
- TCP 8447: VMess WebSocket TLS
- TCP 9446: subscription endpoint (not implemented in pre4)
- TCP 9443 on loopback only: Nginx REALITY fallback

## Validation status

Pre4 performs local syntax/structure checks. It has **not** been validated with the pinned live Xray and sing-box binaries in this build environment, and no client import/connectivity test has been performed. The generated sing-box fields and all protocol options must pass the native `sing-box check` on RackNerd before activation. The generated Xray config must pass `xray run -test`. Do not install these staged configs into production services yet.
