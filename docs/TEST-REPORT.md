# Pre4 local test report

Executed in the build environment on 2026-11-15.

Passed:
- `python3 -m py_compile scripts/*.py`
- `bash -n scripts/*.sh`
- existing domain-mode config validation
- existing IPv4-mode config validation
- synthetic REALITY key-output parser test for `PrivateKey` + `Password (PublicKey)` + `Hash32`
- renderer smoke test in both domain and IPv4 modes
- generated Xray and sing-box JSON parses successfully
- expected four Xray and four sing-box inbounds and expected RackNerd ports are present
- generated REALITY target is `127.0.0.1:9443`

Not tested / not claimed:
- native `xray run -test` (Xray binary is not installed in build environment)
- native `sing-box check` (sing-box binary is not installed in build environment)
- actual TLS certificate files, ACME, Nginx `nginx -t`, systemd service startup
- remote port reachability, provider firewall rules, or client imports/connectivity

All smoke-test credentials were synthetic and discarded. No user credentials or VPS were accessed or changed.
