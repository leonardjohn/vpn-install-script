# Domain-optional addressing and SNI behavior

## Two independent concepts

- `SERVER_ADDRESS`: what the client connects to. This can be an owned DNS name or the VPS public IPv4.
- `REALITY_SNI`: the hostname sent in the REALITY handshake. It must be a hostname and must be compatible with the server's REALITY target configuration.

The public IPv4 is not an SNI value. Do not put an IP literal in `REALITY_SNI`.

## Domain mode

Use an owned DNS name for the client address. Set `REALITY_SNI` to a hostname configured on the REALITY server and supported by its target. The VMISS-derived fallback remains `127.0.0.1:9443`.

For ordinary TLS services, use ACME with DNS names that resolve to the VPS. The same certificate may cover the relevant service hostnames if the SANs are correct.

## IPv4-only mode

Set `SERVER_ADDRESS` to the VPS public IPv4 and manually supply `REALITY_SNI`. Do not derive or invent the SNI from the IP. The SNI must be deliberately selected to match the configured REALITY target and the server's accepted `serverNames`.

For non-REALITY TLS services, this pre-release model uses a self-signed certificate containing the VPS IPv4 as an IP SAN. Such a certificate is not publicly trusted by default. Clients must either install/trust the certificate/issuing CA or explicitly allow insecure certificate verification. The latter weakens server authentication and should be treated as a trade-off, not silently enabled by the installer.

A domainless public HTTPS subscription endpoint has the same certificate trust issue. The final installer should make this explicit and should not silently publish an HTTPS URL that clients cannot validate.

## REALITY compatibility warning

The SNI value is not an arbitrary camouflage string. It must be compatible with the selected REALITY target. The current VMISS design uses `target=127.0.0.1:9443` and `serverNames` containing the web hostnames. The final RackNerd implementation should preserve that local fallback pattern, but it must also verify the actual fallback listener and its TLS behavior before deployment.
