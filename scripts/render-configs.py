#!/usr/bin/env python3
"""Render Xray and sing-box server configs from validated env + per-server secrets.

This renderer writes staged files only. It does not install binaries, alter services,
open ports, issue certificates, or overwrite system configuration.
"""
import argparse, json, os, re, stat, sys
from pathlib import Path


def parse_env(path):
    values = {}
    for no, raw in enumerate(Path(path).read_text().splitlines(), 1):
        s = raw.strip()
        if not s or s.startswith('#'): continue
        if '=' not in s: raise SystemExit(f'Invalid env line {no}')
        k, v = s.split('=', 1); k=k.strip(); v=v.strip().strip('"').strip("'")
        if k in values: raise SystemExit(f'Duplicate config key: {k}')
        values[k]=v
    return values

def required(d, k):
    v=d.get(k, '')
    if not v: raise SystemExit(f'Missing required config: {k}')
    return v

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--config', required=True)
    ap.add_argument('--credentials', required=True)
    ap.add_argument('--output', required=True, help='New staging directory; must not exist')
    a=ap.parse_args()
    cfg=parse_env(a.config)
    # Reuse the strict validator before rendering.
    import subprocess
    subprocess.run([sys.executable, str(Path(__file__).with_name('validate-server-config.py')), a.config], check=True)
    sec_path=Path(a.credentials)
    if sec_path.stat().st_mode & 0o077: raise SystemExit('Credentials file must have mode 0600')
    sec=json.loads(sec_path.read_text())
    for k in ('vless_reality_uuid','vless_xhttp_uuid','trojan_password','vmess_uuid','anytls_password','hysteria2_password','tuic_uuid','tuic_password','shadowsocks_password','reality_short_id','reality_private_key','reality_public_key'):
        required(sec,k)
    out=Path(a.output)
    if out.exists(): raise SystemExit(f'REFUSING to overwrite existing output directory: {out}')
    out.mkdir(mode=0o700, parents=True)
    cert=cfg.get('TLS_CERT_FILE','/etc/ssl/vpn/shared/fullchain.pem')
    key=cfg.get('TLS_KEY_FILE','/etc/ssl/vpn/shared/private.key')
    sni=required(cfg,'REALITY_SNI')
    reality={
      'show': False,
      'target': required(cfg,'REALITY_TARGET'),
      'serverNames': [sni],
      'privateKey': sec['reality_private_key'],
      'shortIds': [sec['reality_short_id']],
      'minClientVer': cfg.get('REALITY_MIN_CLIENT_VER','1.8.2')
    }
    xray={
      'log': {'loglevel':'warning'},
      'inbounds': [
        {'tag':'vless-reality','listen':'0.0.0.0','port':int(cfg['REALITY_PORT']),'protocol':'vless',
         'settings':{'clients':[{'id':sec['vless_reality_uuid'],'flow':cfg.get('REALITY_FLOW','xtls-rprx-vision')}],'decryption':'none'},
         'streamSettings':{'network':'raw','security':'reality','realitySettings':reality}},
        {'tag':'vless-xhttp','listen':'0.0.0.0','port':int(cfg['XHTTP_PORT']),'protocol':'vless',
         'settings':{'clients':[{'id':sec['vless_xhttp_uuid']}],'decryption':'none'},
         'streamSettings':{'network':'xhttp','security':'tls','xhttpSettings':{'path':'/xhttp','mode':'auto'},
          'tlsSettings':{'alpn':['h2','http/1.1'],'minVersion':'1.2','certificates':[{'certificateFile':cert,'keyFile':key}]}}},
        {'tag':'trojan-tls','listen':'0.0.0.0','port':int(cfg['TROJAN_PORT']),'protocol':'trojan',
         'settings':{'clients':[{'password':sec['trojan_password']}]},
         'streamSettings':{'network':'raw','security':'tls','tlsSettings':{'alpn':['http/1.1'],'certificates':[{'certificateFile':cert,'keyFile':key}]}}},
        {'tag':'vmess-ws-tls','listen':'0.0.0.0','port':int(cfg['VMESS_PORT']),'protocol':'vmess',
         'settings':{'clients':[{'id':sec['vmess_uuid'],'alterId':0}]},
         'streamSettings':{'network':'ws','security':'tls','wsSettings':{'path':'/vmess'},
          'tlsSettings':{'alpn':['http/1.1'],'certificates':[{'certificateFile':cert,'keyFile':key}]}}}
      ],
      'outbounds':[{'protocol':'freedom','tag':'direct'}]
    }
    sing={
      'log':{'level':'warn'},
      'inbounds':[
        {'type':'anytls','tag':'anytls-in','listen':'0.0.0.0','listen_port':int(cfg['ANYTLS_PORT']),
         'users':[{'name':'primary','password':sec['anytls_password']}],
         'tls':{'enabled':True,'certificate_path':cert,'key_path':key}},
        {'type':'hysteria2','tag':'hy2-in','listen':'0.0.0.0','listen_port':int(cfg['HY2_PORT']),
         'users':[{'password':sec['hysteria2_password']}],
         'tls':{'enabled':True,'alpn':['h3'],'certificate_path':cert,'key_path':key}},
        {'type':'tuic','tag':'tuic-in','listen':'0.0.0.0','listen_port':int(cfg['TUIC_PORT']),
         'users':[{'uuid':sec['tuic_uuid'],'password':sec['tuic_password']}],
         'congestion_control':'bbr','tls':{'enabled':True,'alpn':['h3'],'certificate_path':cert,'key_path':key}},
        {'type':'shadowsocks','tag':'ss-in','listen':'0.0.0.0','listen_port':int(cfg['SS_PORT']),
         'method':'chacha20-ietf-poly1305','password':sec['shadowsocks_password']}
      ],
      'outbounds':[{'type':'direct','tag':'direct'}]
    }
    (out/'xray-config.json').write_text(json.dumps(xray,indent=2)+'\n')
    (out/'sing-box-config.json').write_text(json.dumps(sing,indent=2)+'\n')
    # Nginx fallback is intentionally a snippet only; caller must include it in an explicitly reviewed server block.
    nginx=f'''# Generated fallback server. Review before enabling.\nserver {{\n    listen 127.0.0.1:{int(cfg['FALLBACK_PORT'])} ssl;\n    server_name {sni};\n    ssl_certificate {cert};\n    ssl_certificate_key {key};\n    ssl_protocols TLSv1.2 TLSv1.3;\n    server_tokens off;\n    root /var/www/html;\n    index index.html;\n    location / {{ try_files $uri $uri/ =404; }}\n}}\n'''
    (out/'nginx-reality-fallback.conf').write_text(nginx)
    for p in out.iterdir(): os.chmod(p,0o600)
    print(f'Rendered staged configuration files into {out}')
    print('Files: xray-config.json, sing-box-config.json, nginx-reality-fallback.conf')
    print('No system configuration or services were changed.')

if __name__=='__main__': main()
