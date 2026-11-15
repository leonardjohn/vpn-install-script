# Roadmap

This pre-release only establishes and validates the server addressing configuration model.

Remaining before a production installer:
1. Pin and verify official Xray and sing-box release artifacts with SHA-256 checksums.
2. Implement OS/package adapters and idempotent backup/restore behavior.
3. Implement Xray and sing-box config generation using current schemas and validate with the real binaries.
4. Implement Nginx fallback and subscription endpoint; validate `nginx -t`.
5. Implement ACME DNS/HTTP issuance and renewal hooks for domain mode.
6. Implement self-signed IP-SAN certificate creation and client trust warnings for IPv4-only mode.
7. Implement firewall detection and provider-neutral instructions; do not guess provider APIs.
8. Test on an isolated Debian 12 VPS, then test all eight protocols and three subscription formats with real clients.
9. Add Debian 13, Ubuntu, AlmaLinux and provider adapters only after Debian 12 passes.
