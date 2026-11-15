#!/usr/bin/env python3
"""Create per-server non-REALITY credentials; no network access required."""
import argparse, json, os, secrets, stat, uuid
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--output', required=True, help='New directory for secrets; must not already exist')
a = p.parse_args()
out = Path(a.output).expanduser()
if out.exists(): raise SystemExit(f'REFUSING: output path already exists: {out}')
out.mkdir(parents=True, mode=0o700)
os.chmod(out, 0o700)
secrets_data = {
    'vless_reality_uuid': str(uuid.uuid4()),
    'vless_xhttp_uuid': str(uuid.uuid4()),
    'trojan_password': secrets.token_urlsafe(32),
    'vmess_uuid': str(uuid.uuid4()),
    'anytls_password': secrets.token_urlsafe(32),
    'hysteria2_password': secrets.token_urlsafe(32),
    'tuic_uuid': str(uuid.uuid4()),
    'tuic_password': secrets.token_urlsafe(32),
    'shadowsocks_password': secrets.token_urlsafe(32),
    'reality_short_id': secrets.token_hex(8),
    'subscription_token': secrets.token_hex(32),
    'reality_keypair': 'GENERATE_WITH_PINNED_XRAY_BINARY_DURING_DEPLOYMENT'
}
path = out / 'credentials.json'
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as f: json.dump(secrets_data, f, indent=2); f.write('\n')
os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)
print(f'Created server credentials at {path}')
print('Permissions: directory 0700, file 0600')
print('REALITY X25519 keypair intentionally deferred to the pinned Xray binary.')
print('Do not paste, upload, commit, or send this file to anyone.')
