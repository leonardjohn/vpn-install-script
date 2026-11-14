# Operations and safety

## Paths

- State and credentials: `/etc/vpn-deploy/` (root-owned; secrets mode 600)
- Xray config: `/usr/local/etc/xray/config.json`
- sing-box config: `/etc/sing-box/config.json`
- Shared certificate: `/etc/ssl/vpn/shared/`
- Subscription files: `/var/lib/vpn-subscription/`
- Nginx site: `/etc/nginx/sites-available/vpn-subscription`
- Installer backup: `/var/backups/vpn-deploy/<UTC timestamp>/`

## Validation

```bash
bash /path/to/vpn-deploy-debian12/scripts/validate.sh
sudo bash /path/to/vpn-deploy-debian12/scripts/show-subscriptions.sh
systemctl status xray sing-box nginx --no-pager
ss -tulpen
```

## Secrets

Never paste `credentials.json`, `subscription-token.txt`, `private.key`, or REALITY private key into chat, tickets, screenshots, or public repositories. Share only the generated subscription URL with the intended client.

## Recovery

The pre-release installer makes a backup before changing managed configuration and stores the full non-secret server configuration at `/etc/vpn-deploy/server.env`. Do not blindly restore the entire backup over a running system. Stop only the affected service, compare the backed-up file, restore the intended file, validate, then start the service.

## Reinstallation / upgrades

Version 0.1.0-pre1 intentionally refuses a second install. It does not yet implement an in-place upgrade or uninstall command. Do not delete `/etc/vpn-deploy/state.json` to bypass this protection.
