#!/usr/bin/env python3
import ipaddress, re, sys
from pathlib import Path

cfg_path = Path(sys.argv[1] if len(sys.argv) > 1 else 'config/server.env')
if not cfg_path.is_file():
    raise SystemExit(f'ERROR: config file not found: {cfg_path}')
values = {}
for no, raw in enumerate(cfg_path.read_text().splitlines(), 1):
    line = raw.strip()
    if not line or line.startswith('#'):
        continue
    if '=' not in line:
        raise SystemExit(f'ERROR: invalid config line {no}')
    k, v = line.split('=', 1)
    k, v = k.strip(), v.strip().strip('"').strip("'")
    if not re.fullmatch(r'[A-Z][A-Z0-9_]*', k):
        raise SystemExit(f'ERROR: invalid key on line {no}')
    if k in values:
        raise SystemExit(f'ERROR: duplicate key {k} on line {no}')
    values[k] = v

def get(k, default=''):
    return values.get(k, default)
def need(k):
    if not get(k): raise SystemExit(f'ERROR: {k} must be set')
def hostname(s):
    if len(s) > 253 or not s or s.endswith('.'):
        return False
    labels = s.split('.')
    return all(len(x) <= 63 and re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?', x) for x in labels)
def port(k):
    need(k)
    try: n = int(get(k))
    except ValueError: raise SystemExit(f'ERROR: {k} must be an integer')
    if not 1 <= n <= 65535: raise SystemExit(f'ERROR: {k} out of range')
    return n
mode = get('ADDRESS_MODE')
if mode not in ('domain', 'ipv4'): raise SystemExit('ERROR: ADDRESS_MODE must be domain or ipv4')
for k in ('SERVER_ADDRESS','REALITY_TARGET','REALITY_SNI','REALITY_FLOW','REALITY_MIN_CLIENT_VER','TLS_CERT_MODE'):
    need(k)
try: ipaddress.ip_address(get('SERVER_ADDRESS'))
except ValueError: server_is_ip = False
else: server_is_ip = True
if mode == 'domain':
    if server_is_ip or not hostname(get('SERVER_ADDRESS')): raise SystemExit('ERROR: domain mode requires SERVER_ADDRESS to be a hostname')
    need('BASE_DOMAIN'); need('TLS_CERT_HOST'); need('SUBSCRIPTION_HOST'); need('ACME_EMAIL')
    if not hostname(get('TLS_CERT_HOST')) or not hostname(get('SUBSCRIPTION_HOST')): raise SystemExit('ERROR: TLS_CERT_HOST and SUBSCRIPTION_HOST must be hostnames')
    if get('TLS_CERT_MODE') != 'acme': raise SystemExit('ERROR: domain mode requires TLS_CERT_MODE=acme')
    if '@' not in get('ACME_EMAIL'): raise SystemExit('ERROR: ACME_EMAIL does not look like an email address')
else:
    try: ipaddress.IPv4Address(get('SERVER_ADDRESS'))
    except ValueError: raise SystemExit('ERROR: ipv4 mode requires a valid IPv4 SERVER_ADDRESS')
    if get('BASE_DOMAIN') or get('TLS_CERT_HOST') or get('SUBSCRIPTION_HOST') or get('ACME_EMAIL'):
        raise SystemExit('ERROR: in ipv4 mode BASE_DOMAIN, TLS_CERT_HOST, SUBSCRIPTION_HOST and ACME_EMAIL must be empty in this release')
    if get('TLS_CERT_MODE') != 'self_signed': raise SystemExit('ERROR: ipv4 mode requires TLS_CERT_MODE=self_signed')
if not hostname(get('REALITY_SNI')): raise SystemExit('ERROR: REALITY_SNI must be a hostname, never an IP or URL')
if not re.fullmatch(r'127\.0\.0\.1:[0-9]{1,5}', get('REALITY_TARGET')): raise SystemExit('ERROR: REALITY_TARGET must be loopback IPv4 host:port')
target_port = int(get('REALITY_TARGET').rsplit(':',1)[1])
if not 1 <= target_port <= 65535: raise SystemExit('ERROR: REALITY_TARGET port out of range')
ports = {k: port(k) for k in ('REALITY_PORT','XHTTP_PORT','ANYTLS_PORT','HY2_PORT','TUIC_PORT','SS_PORT','TROJAN_PORT','VMESS_PORT','SUBSCRIPTION_PORT','FALLBACK_PORT')}
if len(set(ports.values())) != len(ports): raise SystemExit('ERROR: configured ports must be unique')
if ports['FALLBACK_PORT'] != target_port: raise SystemExit('ERROR: FALLBACK_PORT must match REALITY_TARGET port')
if ports['REALITY_PORT'] == 22: raise SystemExit('ERROR: VPN port cannot replace SSH port 22')
print('Configuration syntax: PASS')
print(f'Address mode: {mode}')
print(f'Client connection address: {get("SERVER_ADDRESS")}')
print(f'REALITY SNI: {get("REALITY_SNI")}')
print(f'REALITY target: {get("REALITY_TARGET")}')
print(f'TLS certificate mode: {get("TLS_CERT_MODE")}')
print('Port plan: PASS (all configured ports are unique)')
print('NOTE: DNS ownership, SNI/target compatibility, certificate issuance and live port availability are not proven by this syntax check.')
