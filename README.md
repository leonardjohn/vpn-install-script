# VPN Deployment Toolkit — Debian 12 pre-release 5

Pre5 adds a pinned, checksum-verifying binary-only installer for the Xray and sing-box versions used by the VMISS reference architecture. It intentionally does not activate services or deploy configs.

## Install only the binaries

Review `docs/BINARY-INSTALL.md`, then on a fresh Debian 12 amd64 host:

```bash
sudo bash scripts/install-pinned-binaries.sh
sudo bash scripts/check-binaries.sh
```

The script downloads exact release assets from official GitHub repositories, requires SHA-256 digests from the GitHub release API, verifies both archives, and refuses to overwrite existing executables. It installs only `/usr/local/bin/xray` and `/usr/local/bin/sing-box`.

## Existing staged engine

Pre4 configuration generation remains available:

```bash
sudo python3 scripts/generate-credentials.py --output /root/vpn-deploy-secrets
sudo python3 scripts/generate-reality-keys.py --credentials /root/vpn-deploy-secrets/credentials.json --xray /usr/local/bin/xray
sudo python3 scripts/render-configs.py --config config/server.env --credentials /root/vpn-deploy-secrets/credentials.json --output /root/vpn-deploy-staging
```

The rendered configurations are still staged only. Native config validation, certificates, Nginx activation, systemd services, subscriptions, and rollback are not yet complete. Do not treat pre5 as a full one-click VPN installer.

See `docs/BINARY-INSTALL.md`, `docs/ENGINE-DESIGN.md`, `docs/ADDRESSING-AND-SNI.md`, and `docs/TEST-REPORT.md`.
