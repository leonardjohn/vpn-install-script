# Roadmap

## Completed in pre3
- Domain and IPv4 address modes remain separate from REALITY SNI.
- Strict configuration validator, including port uniqueness and IPv4 validation.
- Read-only Debian 12/amd64 server preflight.
- Per-server UUID/password/token generation with root-only file permissions.
- REALITY keypair generation deliberately deferred to the pinned Xray binary.

## Remaining before a production installer
1. Pin and verify official Xray and sing-box release artifacts with published SHA-256 checksums.
2. Generate Xray and sing-box configurations from the generated credentials and validate them with those exact binaries.
3. Implement Nginx local fallback and subscription endpoint; validate with `nginx -t`.
4. Implement ACME DNS/HTTP issuance and renewal hooks for domain mode.
5. Implement self-signed IP-SAN certificate creation and client trust warnings for IPv4-only mode. Decide whether public HTTPS subscription is supported without a domain.
6. Implement firewall detection and provider-neutral instructions; do not guess provider APIs.
7. Implement transactional installation, backup/restore, service hardening, and idempotent upgrades.
8. Test all eight protocols and all three subscription formats with real clients on isolated Debian 12.
9. Add Debian 13, Ubuntu, AlmaLinux and provider adapters only after Debian 12 passes.

## Security constraints
- Never reuse credentials, REALITY keys, certificates, or subscription tokens across VPS instances.
- Never silently enable TLS `allowInsecure` in client profiles.
- Never overwrite existing service configurations without an explicit backup/replace decision.
- Never assume the cloud provider firewall is open because the guest OS firewall is empty.
