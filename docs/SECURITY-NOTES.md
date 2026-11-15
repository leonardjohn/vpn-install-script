# Security and behavior notes

- `SERVER_ADDRESS` is the client dial address; `REALITY_SNI` is a hostname sent in the REALITY handshake. They are independent.
- A user-supplied SNI is not automatically valid. The server must serve/accept that name through the configured REALITY target, and the target must satisfy REALITY's TLS/handshake requirements. This package only validates syntax.
- The VMISS-derived local fallback target is `127.0.0.1:9443`. A later installer must create and verify the fallback service before starting the REALITY inbound.
- IPv4-only mode uses a self-signed IP-SAN certificate for ordinary TLS services. This is not publicly trusted. Prefer installing/trusting the CA/certificate on clients. Disabling certificate verification weakens authentication and must be an explicit client-side choice.
- A domainless subscription endpoint over HTTPS has the same trust issue. No public subscription endpoint is enabled by this pre-release.
- Generated credentials are sensitive. The credentials directory must remain mode 0700 and its JSON file mode 0600.
