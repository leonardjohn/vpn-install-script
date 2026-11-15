#!/usr/bin/env python3
"""Offline smoke tests for pre4 renderer. Uses synthetic, non-secret fixtures."""
import json, os, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as td:
    t=Path(td); secrets_dir=t/'secrets'; secrets_dir.mkdir(mode=0o700)
    # Synthetic values only; never valid production credentials.
    creds={
      'vless_reality_uuid':'11111111-1111-4111-8111-111111111111',
      'vless_xhttp_uuid':'22222222-2222-4222-8222-222222222222',
      'trojan_password':'test-only-trojan-password',
      'vmess_uuid':'33333333-3333-4333-8333-333333333333',
      'anytls_password':'test-only-anytls-password',
      'hysteria2_password':'test-only-hy2-password',
      'tuic_uuid':'44444444-4444-4444-8444-444444444444',
      'tuic_password':'test-only-tuic-password',
      'shadowsocks_password':'test-only-ss-password',
      'reality_short_id':'a1b2c3d4',
      'reality_private_key':'A'*43,
      'reality_public_key':'B'*43
    }
    cp=secrets_dir/'credentials.json'; cp.write_text(json.dumps(creds)); os.chmod(cp,0o600)
    for mode,config in [('domain','server.env.example'),('ipv4','server-ipv4.env.example')]:
        out=t/f'out-{mode}'
        subprocess.run([sys.executable,str(ROOT/'scripts/render-configs.py'),'--config',str(ROOT/'config'/config),'--credentials',str(cp),'--output',str(out)],check=True,stdout=subprocess.DEVNULL)
        x=json.loads((out/'xray-config.json').read_text()); s=json.loads((out/'sing-box-config.json').read_text())
        assert len(x['inbounds'])==4 and len(s['inbounds'])==4
        assert [i['port'] for i in x['inbounds']]==[9444,9445,8446,8447]
        assert [i['listen_port'] for i in s['inbounds']]==[2053,8444,8445,8388]
        r=x['inbounds'][0]['streamSettings']['realitySettings']
        assert r['target']=='127.0.0.1:9443'
        assert r['serverNames']
        assert (out/'nginx-reality-fallback.conf').is_file()
print('Pre4 engine smoke tests: PASS (domain + IPv4 modes; synthetic secrets only)')
