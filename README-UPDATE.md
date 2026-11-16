# VPN toolkit Pre5 corrective update overlay

This is a manually applied overlay for the public `vpn-install-script` repository. It is designed for local review and commit by the repository owner; it does not connect to GitHub or push changes.

## Included files

- `scripts/install-pinned-binaries.sh`: replacement for the Pre5 binary installer. Fixes the multi-line `jq | head -n1` bug by extracting exactly one compact JSON object. Adds explicit HTTP/JSON/asset validation, clearer failures, archive SHA-256 verification, architecture checks, pre-publication executable checks, and refuses to overwrite existing binaries.
- `scripts/server-preflight-report.sh`: new read-only environment report covering OS/architecture, dependencies, existing Xray/sing-box binaries and versions, systemd units, disk, listening ports, and effective SSH authentication settings. It makes no changes.
- `tests/test-installer-metadata.sh`: offline regression test for the JSON extraction defect and missing-asset handling.

## Apply on your Mac

1. Make a backup or create a branch in your local repository.
2. Extract this ZIP.
3. Copy the included `scripts/install-pinned-binaries.sh` over the existing file.
4. Copy `scripts/server-preflight-report.sh` into your repository's `scripts/` directory.
5. Copy `tests/test-installer-metadata.sh` into `tests/`.
6. Review the diff before committing.

Example from the repository root (adjust the extracted folder path):

```bash
cp /path/to/extracted/scripts/install-pinned-binaries.sh scripts/install-pinned-binaries.sh
cp /path/to/extracted/scripts/server-preflight-report.sh scripts/server-preflight-report.sh
cp /path/to/extracted/tests/test-installer-metadata.sh tests/test-installer-metadata.sh
chmod 755 scripts/install-pinned-binaries.sh scripts/server-preflight-report.sh tests/test-installer-metadata.sh
bash -n scripts/install-pinned-binaries.sh scripts/server-preflight-report.sh tests/test-installer-metadata.sh
bash tests/test-installer-metadata.sh
```

Then inspect:

```bash
git diff --check
git status --short
git diff -- scripts/install-pinned-binaries.sh
```

Commit and push only after reviewing. Suggested commit message: `fix binary metadata parsing and add server preflight report`.

## Important scope notes

- This is an overlay, not a full replacement of the repository and not a complete rework of `README.md`, `docs/BINARY-INSTALL.md`, or `scripts/check-binaries.sh`. Those existing files are intentionally not overwritten because their full current contents were not part of the RackNerd transcript used to prepare this package.
- The preflight report is informational. It does not modify SSH, install dependencies, open ports, or remove existing binaries.
- The installer remains Debian 12 amd64-specific as in Pre5.
- The installer downloads release metadata live from GitHub and requires GitHub's API to provide a SHA-256 digest for each asset. It refuses to install if the digest is missing or malformed.
- No installer was run by creating this package. Do not rerun the RackNerd installation until you have reviewed and pushed the corrected code, then download the new pinned commit and verify its hash.
