#!/usr/bin/env python3
"""Generate REALITY X25519 keys using the installed Xray binary."""
import argparse, json, os, re, subprocess, tempfile
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument('--credentials', required=True, help='Existing credentials.json path')
ap.add_argument('--xray', default='xray', help='Xray binary path')
a = ap.parse_args()
p = Path(a.credentials).expanduser()
if not p.is_file(): raise SystemExit(f'ERROR: credentials file not found: {p}')
if p.stat().st_mode & 0o077: raise SystemExit('ERROR: credentials file must not be accessible by group/others (chmod 600)')
try: data = json.loads(p.read_text())
except Exception as e: raise SystemExit(f'ERROR: invalid credentials JSON: {e}')
if data.get('reality_private_key') or data.get('reality_public_key'):
    raise SystemExit('REFUSING: REALITY key fields already exist; back up and rotate explicitly instead of overwriting')
try:
    proc = subprocess.run([a.xray, 'x25519'], check=True, text=True, capture_output=True)
except FileNotFoundError: raise SystemExit(f'ERROR: Xray binary not found: {a.xray}')
except subprocess.CalledProcessError as e: raise SystemExit(f'ERROR: xray x25519 failed: {e.stderr or e.stdout}')
out = proc.stdout + '\n' + proc.stderr
priv = pub = None
for line in out.splitlines():
    if ':' not in line: continue
    label, value = line.split(':', 1)
    label = re.sub(r'[^a-z]', '', label.lower())
    value = value.strip()
    if label == 'privatekey': priv = value
    elif label in ('password', 'passwordpublickey', 'publickey'): pub = value
if not priv or not pub:
    raise SystemExit('ERROR: could not parse Xray x25519 output. No secrets were written. Review Xray version/output manually.')
if not re.fullmatch(r'[A-Za-z0-9_-]{40,50}', priv) or not re.fullmatch(r'[A-Za-z0-9_-]{40,50}', pub):
    raise SystemExit('ERROR: Xray returned unexpected key encoding/length. No secrets were written.')
data['reality_private_key'] = priv
data['reality_public_key'] = pub
fd, tmpname = tempfile.mkstemp(prefix='.credentials.', dir=str(p.parent))
try:
    with os.fdopen(fd, 'w') as f:
        json.dump(data, f, indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
    os.chmod(tmpname, 0o600)
    os.replace(tmpname, p)
finally:
    if os.path.exists(tmpname): os.unlink(tmpname)
print('REALITY X25519 keypair generated with Xray and saved to credentials.json.')
print('Private key is server-only. Public key is used by clients. Never share credentials.json.')
