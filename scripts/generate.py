#!/usr/bin/env python3
"""Generate server-unique credentials. Run once per new VPS."""
import json, os, secrets, uuid
from pathlib import Path

def read_env(path):
    values = {}
    for raw in Path(path).read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line: continue
        k, v = line.split('=', 1)
        values[k.strip()] = v.strip().strip('"').strip("'")
    return values

def token(n=32): return secrets.token_urlsafe(n)

def main():
    cfg = read_env(os.environ['VPN_DEPLOY_CONFIG'])
    root = Path('/etc/vpn-deploy/secrets')
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    d = {
        'vless_uuid': str(uuid.uuid4()), 'vmess_uuid': str(uuid.uuid4()),
        'tuic_uuid': str(uuid.uuid4()), 'tuic_password': token(24),
        'anytls_password': token(32), 'hy2_password': token(32),
        'ss_password': token(24), 'trojan_password': token(32),
        'sub_token': secrets.token_hex(32), 'reality_short_id': secrets.token_hex(8),
        'xhttp_path': cfg['XHTTP_PATH'], 'vmess_path': '/vmess-rn',
    }
    p = root / 'credentials.json'
    p.write_text(json.dumps(d, indent=2) + '\n'); p.chmod(0o600)
    t = root / 'subscription-token.txt'
    t.write_text(d['sub_token'] + '\n'); t.chmod(0o600)

if __name__ == '__main__': main()
