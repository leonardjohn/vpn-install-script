# Provider firewall checklist — RackNerd

The toolkit does not guess or modify provider firewall policies. In the RackNerd customer portal, inspect any VPS firewall/security-group feature. If one is present, add inbound rules below. If RackNerd provides no such firewall, confirm the host/network policy with its documentation/support.

| Protocol | Port | Purpose |
|---|---:|---|
| TCP | 22 | SSH administration (keep your current SSH access) |
| TCP | 80 | ACME HTTP-01 challenge and renewal |
| TCP | 9444 | VLESS REALITY |
| TCP | 9445 | VLESS XHTTP TLS |
| TCP | 2053 | AnyTLS |
| UDP | 8444 | Hysteria2 |
| UDP | 8445 | TUIC |
| TCP + UDP | 8388 | Shadowsocks |
| TCP | 8446 | Trojan TLS |
| TCP | 8447 | VMess WebSocket TLS |
| TCP | 9446 | Subscription HTTPS |

Do not expose TCP 9443: it is loopback-only fallback. Do not remove or restrict TCP 22 until a second SSH session has verified access.
