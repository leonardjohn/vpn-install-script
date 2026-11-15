# Candidate upstream versions

The VMISS reference deployment used Xray v26.10.31 and sing-box v1.14.4. These are candidate pins for parity, not an installer lockfile yet.

- Xray official release: https://github.com/XTLS/Xray-core/releases/tag/v26.10.31
- sing-box official release: https://github.com/SagerNet/sing-box/releases/tag/v1.14.4

Before writing an installer, resolve the exact Linux amd64 asset names and official SHA-256 values for these tags and store them in a reviewed lockfile. The installer must reject checksum mismatches and must never use an unpinned `latest` download.
