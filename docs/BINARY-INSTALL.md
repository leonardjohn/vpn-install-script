# Pinned binary installation — pre5

This step installs only the Xray and sing-box command-line executables. It does **not** install or enable systemd services, write server configs, open ports, issue certificates, change firewall rules, or start listeners.

Pinned releases match the versions used in the VMISS reference deployment:

- Xray-core `v26.10.31`, asset `Xray-linux-64.zip`
- sing-box `v1.14.4`, asset `sing-box-1.14.4-linux-amd64.tar.gz`

The installer retrieves release metadata from the official GitHub API and requires a `sha256:` digest for each exact asset. It refuses to download/install if the digest is missing or invalid. It also refuses to overwrite any existing `xray` or `sing-box` executable.

## Run on a fresh Debian 12 amd64 server

```bash
sudo bash scripts/install-pinned-binaries.sh
sudo bash scripts/check-binaries.sh
```

Required utilities: `curl`, `jq`, `unzip`, `tar`, `sha256sum`, `file`, `find`, and `install`. If needed, install the Debian packages with `apt-get install -y curl jq unzip tar coreutils file findutils`. The script deliberately does not install missing packages automatically.

Expected effects:

- Adds `/usr/local/bin/xray`
- Adds `/usr/local/bin/sing-box`
- Uses a temporary root-only directory under `/var/tmp`, removed on exit
- Does not create users, groups, config directories, services, certificates, or listeners

If a GitHub API asset digest is unavailable, the script stops rather than trusting an unverified download. No fallback to a third-party mirror is used.
