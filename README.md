# VPN Deployment Toolkit — Debian 12 pre-release 2

This package is a configuration-model and validation increment for the reusable deployment toolkit. It is **not yet a production installer**. It does not install Xray, sing-box, Nginx, ACME, firewall rules, or publish DNS records.

## What changed in pre2

- Separates the server's connection address from TLS/REALITY SNI.
- Supports `ADDRESS_MODE=domain` and `ADDRESS_MODE=ipv4`.
- Requires an explicitly supplied `REALITY_SNI` in both modes. In IPv4 mode, the SNI is never guessed from the IP.
- Keeps the VMISS REALITY fallback pattern: `REALITY_TARGET=127.0.0.1:9443`.
- Adds explicit TLS certificate modes. Domain mode uses ACME; IPv4-only mode uses a self-signed certificate with the server IPv4 in its SAN. Clients must explicitly trust that certificate or opt into insecure verification; this is not equivalent to a publicly trusted certificate.

## Validate the example

```bash
cp config/server.env.example config/server.env
# Edit config/server.env locally; do not share private keys or tokens.
bash scripts/validate-server-config.sh config/server.env
```

The validator only checks configuration consistency. It does not install or start services.

## Important distinction

`SERVER_ADDRESS` is the address clients dial. `REALITY_SNI` is the hostname sent in the REALITY handshake and must be compatible with the configured REALITY target. They are not interchangeable. An IP address does not become a valid SNI hostname.

For domainless deployments, choose an SNI hostname that is genuinely supported by the REALITY target and that you are authorized to use. Do not enter an arbitrary hostname merely because it resolves. The later installer must validate the target/SNI relationship and document the exact client settings.
