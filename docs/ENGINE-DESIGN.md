# Engine design and validation boundaries

## Configuration ownership

The renderer writes staged files only. It never writes to `/usr/local/etc/xray`, `/etc/sing-box`, `/etc/nginx`, `/etc/ssl`, or systemd directories. Promotion into system paths is a separate deployment step with backup and rollback.

## Xray

Four inbounds reproduce the VMISS split:
- VLESS REALITY with `network: raw`, `target: 127.0.0.1:9443`, explicit SNI, generated private key and short ID.
- VLESS XHTTP over TLS at `/xhttp`.
- Trojan over TLS.
- VMess WebSocket over TLS at `/vmess`.

## sing-box

Four inbounds are generated:
- AnyTLS
- Hysteria2
- TUIC (BBR congestion control)
- Shadowsocks (`chacha20-ietf-poly1305`)

The sing-box schema is version-sensitive. Always run `sing-box check -c` with the exact pinned binary before installing or restarting the service. A JSON parse alone is not proof of schema validity.

## REALITY key output

The helper accepts Xray's current output labels `PrivateKey:` and `Password (PublicKey):` (also `Password:`), where Password is the client-side public key. `Hash32` is not used for this classic REALITY configuration. See official Xray docs and upstream discussion in the project references.

## Fallback

A loopback-only Nginx server snippet is emitted for `127.0.0.1:9443` with TLS using the shared cert/key. It is a snippet, not a complete Nginx site; it must be reviewed and integrated by a later installer step. The certificate must be valid for the selected SNI in domain mode, or include that DNS SAN (and the server IP SAN for TLS-by-IP use) in IPv4 mode.

## Not implemented yet

Binary installation/checksum pinning, ACME issuance and renewal, self-signed certificate generation, systemd units, Nginx integration, subscription endpoint, subscription formats, firewall/provider adapters, rollback and live client tests.
