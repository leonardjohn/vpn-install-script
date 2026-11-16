# Corrective update v2 — apply to the existing repository

This is an **overlay**, not a complete repository replacement. It contains:
- a corrected `scripts/install-pinned-binaries.sh`
- a stronger `tests/test-installer-metadata.sh`

## Apply on your Mac

1. Unzip this package.
2. Copy the two files into the matching paths in your local `vpn-install-script` checkout, replacing those files.
3. Review the changes:
   ```bash
   git diff -- scripts/install-pinned-binaries.sh tests/test-installer-metadata.sh
   ```
4. Run:
   ```bash
   bash -n scripts/install-pinned-binaries.sh
   bash -n tests/test-installer-metadata.sh
   bash tests/test-installer-metadata.sh
   git diff --check
   ```
5. Commit and push the changes yourself.

Do not run the installer on RackNerd until the new commit has been reviewed and verified there.

## What changed

- Uses compact `jq -c` output and removes the broken `head -n1` truncation.
- Requires exactly one asset with the expected name.
- Validates GitHub API JSON, download URL, non-empty archive, and SHA-256 digest.
- Checks both extracted binaries before placement.
- Checks destination paths and adds rollback if placement of the second binary fails.
- Regression test checks the production installer source as well as the JSON extraction behavior.

The installer still only installs the two binaries. It does not configure services, certificates, firewall rules, users, or listeners.
