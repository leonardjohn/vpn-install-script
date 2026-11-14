# VPN Deploy Toolkit — Debian 12 (pre-release)

Version: 0.1.0-pre1  
Target: Debian GNU/Linux 12 (Bookworm), amd64  
Reference architecture: the user's existing VMISS deployment.

> **Pre-release warning:** This is an initial deployment candidate, not a production-certified installer. It has shell syntax and static consistency checks, but has not yet been run on the RackNerd VPS or validated against live Xray/sing-box binaries and client applications. Do not run it on VMISS. Test only on the clean RackNerd server after reviewing `config/racknerd.env` and the firewall checklist.

## Included services

- Xray: VLESS REALITY (TCP 9444), VLESS XHTTP+TLS (TCP 9445), Trojan+TLS (TCP 8446), VMess WebSocket+TLS (TCP 8447)
- sing-box: AnyTLS (TCP 2053), Hysteria2 (UDP 8444), TUIC (UDP 8445), Shadowsocks (TCP+UDP 8388)
- Nginx: HTTP ACME challenge (TCP 80), HTTPS subscription (TCP 9446), loopback fallback (TCP 9443)
- Subscription outputs: Mihomo YAML, Shadowrocket URI/Base64, v2rayNG Base64

## Layout

```text
vpn-deploy-debian12/
├── install.sh
├── config/racknerd.env.example
├── lib/common.sh
├── scripts/generate.py
├── scripts/build_configs.py
├── scripts/validate.sh
├── scripts/show-subscriptions.sh
├── docs/FIREWALL.md
└── docs/OPERATIONS.md
```

## Before installation

1. Create the DNS records listed in `config/racknerd.env.example`; all must be DNS-only and point to this VPS.
2. Allow inbound TCP 22, 80, 9444, 9445, 2053, 8446, 8447, 9446 and UDP 8444, 8445, 8388 (plus TCP 8388).
3. Ensure no other service is using these ports.
4. Copy the example configuration to `config/racknerd.env`, set a valid `ACME_EMAIL`, and review the REALITY camouflage target. The default Microsoft target is only an example; the installer checks TCP reachability but does not guarantee it is an ideal REALITY target.
5. Review all values. Never share the generated secrets.

## Install

Run as root on a clean Debian 12 amd64 VPS:

```bash
cp config/racknerd.env.example config/racknerd.env
nano config/racknerd.env
chmod 600 config/racknerd.env
sudo bash install.sh --config config/racknerd.env
```

The installer creates the three subscription URLs in `/etc/vpn-deploy/secrets/subscription-urls.txt` (root-only). Read them after installation with `sudo bash scripts/show-subscriptions.sh`. The installer is intentionally fail-closed. It refuses non-Debian-12 systems, non-amd64 architecture, occupied ports, existing Xray/sing-box/Nginx services, or an existing toolkit state directory. It creates a timestamped backup before writing service configuration. It does not configure a provider firewall or Cloudflare API.

## Versions

Defaults are pinned to Xray `26.10.31` and sing-box `1.14.4`, matching the known-good VMISS baseline recorded during toolkit planning. Update versions only after testing the release on a disposable VPS.

## Important limitations of pre-release 0.1.0

- The installer uses the official Xray install script and the official sing-box GitHub release archive. The Xray installer is the upstream installer; this pre-release does not yet pin a separately verified SHA-256 for the sing-box archive.
- Certificate issuance uses ACME HTTP-01 via Nginx webroot. TCP 80 must be reachable from the public internet and remain available for renewal.
- Cloudflare DNS records are expected to be created manually; orange-cloud proxying must be disabled.
- Provider firewalls are not changed automatically.
- There is no automated multi-provider API adapter yet.
- Re-running installation is deliberately blocked. If an installation fails after packages have been installed, do not rerun it; preserve the output and inspect the partial state before recovery. Backup/restore and upgrade workflows will be added only after the first deployment has been tested.
- The generated client profiles are candidate profiles and require import/connection testing in the target clients before the release can be considered stable. The REALITY target (`REALITY_DEST` and `REALITY_SNI`) is a starting example, not a measured recommendation; confirm it is reachable and suitable from this VPS before installation.
