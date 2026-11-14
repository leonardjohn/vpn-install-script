#!/usr/bin/env python3
"""Render Xray, sing-box, Nginx and client subscription artifacts."""
import base64, json, os, urllib.parse
from pathlib import Path


def envfile(path):
    d = {}
    for raw in Path(path).read_text().splitlines():
        s = raw.strip()
        if not s or s.startswith('#') or '=' not in s: continue
        k,v=s.split('=',1); d[k.strip()]=v.strip().strip('"').strip("'")
    return d

def enc(s): return urllib.parse.quote(str(s), safe='')
def b64(s): return base64.b64encode(s.encode()).decode()
def uri(label, host, port, query, user, scheme):
    return f'{scheme}://{user}@{host}:{port}?{query}#{enc(label)}'

def main():
    cfg = envfile(os.environ.get('VPN_DEPLOY_CONFIG', '/etc/vpn-deploy/server.env'))
    sec = json.loads(Path('/etc/vpn-deploy/secrets/credentials.json').read_text())
    cert='/etc/ssl/vpn/shared/fullchain.pem'; key='/etc/ssl/vpn/shared/private.key'
    # Xray inbound configuration.
    xray = {
      'log': {'loglevel':'warning'},
      'inbounds': [
        {'listen':'0.0.0.0','port':int(cfg['PORT_REALITY']),'protocol':'vless','settings':{'clients':[{'id':sec['vless_uuid'],'flow':'xtls-rprx-vision'}],'decryption':'none'},'streamSettings':{'network':'raw','security':'reality','realitySettings':{'show':False,'dest':cfg['REALITY_DEST'],'serverNames':[cfg['REALITY_SNI']],'privateKey':sec['reality_private'],'shortIds':[sec['reality_short_id']]}}},
        {'listen':'0.0.0.0','port':int(cfg['PORT_XHTTP']),'protocol':'vless','settings':{'clients':[{'id':sec['vless_uuid']}],'decryption':'none'},'streamSettings':{'network':'xhttp','security':'tls','tlsSettings':{'serverName':cfg['XHTTP_HOST'],'certificates':[{'certificateFile':cert,'keyFile':key}]},'xhttpSettings':{'path':sec['xhttp_path']}}},
        {'listen':'0.0.0.0','port':int(cfg['PORT_TROJAN']),'protocol':'trojan','settings':{'clients':[{'password':sec['trojan_password']}]},'streamSettings':{'network':'raw','security':'tls','tlsSettings':{'serverName':cfg['TROJAN_HOST'],'certificates':[{'certificateFile':cert,'keyFile':key}]}}},
        {'listen':'0.0.0.0','port':int(cfg['PORT_VMESS']),'protocol':'vmess','settings':{'clients':[{'id':sec['vmess_uuid'],'alterId':0}]},'streamSettings':{'network':'ws','security':'tls','tlsSettings':{'serverName':cfg['VMESS_HOST'],'certificates':[{'certificateFile':cert,'keyFile':key}]},'wsSettings':{'path':sec['vmess_path']}}},
      ], 'outbounds':[{'protocol':'freedom','tag':'direct'}]
    }
    Path('/usr/local/etc/xray').mkdir(parents=True,exist_ok=True)
    Path('/usr/local/etc/xray/config.json').write_text(json.dumps(xray,indent=2)+'\n')
    # sing-box inbound configuration. Current stable schema is validated by sing-box check during install.
    sb={'log':{'level':'warn'},'inbounds':[
      {'type':'anytls','tag':'anytls-in','listen':'0.0.0.0','listen_port':int(cfg['PORT_ANYTLS']),'users':[{'name':'rn','password':sec['anytls_password']}],'tls':{'enabled':True,'certificate_path':cert,'key_path':key}},
      {'type':'hysteria2','tag':'hy2-in','listen':'0.0.0.0','listen_port':int(cfg['PORT_HY2']),'users':[{'password':sec['hy2_password']}],'tls':{'enabled':True,'certificate_path':cert,'key_path':key}},
      {'type':'tuic','tag':'tuic-in','listen':'0.0.0.0','listen_port':int(cfg['PORT_TUIC']),'users':[{'name':'rn','uuid':sec['tuic_uuid'],'password':sec['tuic_password']}],'congestion_control':'bbr','tls':{'enabled':True,'alpn':['h3'],'certificate_path':cert,'key_path':key}},
      {'type':'shadowsocks','tag':'ss-in','listen':'0.0.0.0','listen_port':int(cfg['PORT_SS']),'method':'chacha20-ietf-poly1305','password':sec['ss_password']}
    ],'outbounds':[{'type':'direct','tag':'direct'}]}
    Path('/etc/sing-box').mkdir(parents=True,exist_ok=True)
    Path('/etc/sing-box/config.json').write_text(json.dumps(sb,indent=2)+'\n')
    # URI subscriptions.
    nodes=[]
    nodes.append(uri('RackNerd VLESS REALITY',cfg['REALITY_HOST'],cfg['PORT_REALITY'],f"encryption=none&security=reality&sni={enc(cfg['REALITY_SNI'])}&fp=chrome&pbk={enc(sec['reality_public'])}&sid={sec['reality_short_id']}&type=tcp&flow=xtls-rprx-vision",sec['vless_uuid'],'vless'))
    nodes.append(uri('RackNerd VLESS XHTTP',cfg['XHTTP_HOST'],cfg['PORT_XHTTP'],f"encryption=none&security=tls&sni={enc(cfg['XHTTP_HOST'])}&fp=chrome&type=xhttp&path={enc(sec['xhttp_path'])}",sec['vless_uuid'],'vless'))
    nodes.append(uri('RackNerd AnyTLS',cfg['ANYTLS_HOST'],cfg['PORT_ANYTLS'],f"security=tls&sni={enc(cfg['ANYTLS_HOST'])}",sec['anytls_password'],'anytls'))
    nodes.append(uri('RackNerd Hysteria2',cfg['HY2_HOST'],cfg['PORT_HY2'],f"sni={enc(cfg['HY2_HOST'])}&alpn=h3",sec['hy2_password'],'hysteria2'))
    nodes.append(f"tuic://{enc(sec['tuic_uuid'])}:{enc(sec['tuic_password'])}@{cfg['TUIC_HOST']}:{cfg['PORT_TUIC']}?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni={enc(cfg['TUIC_HOST'])}#RackNerd%20TUIC")
    ss_user=b64('chacha20-ietf-poly1305:'+sec['ss_password'])
    nodes.append(f"ss://{ss_user}@{cfg['SS_HOST']}:{cfg['PORT_SS']}#RackNerd%20Shadowsocks")
    nodes.append(uri('RackNerd Trojan TLS',cfg['TROJAN_HOST'],cfg['PORT_TROJAN'],f"security=tls&sni={enc(cfg['TROJAN_HOST'])}&type=tcp",sec['trojan_password'],'trojan'))
    vm={'v':'2','ps':'RackNerd VMess WS TLS','add':cfg['VMESS_HOST'],'port':str(cfg['PORT_VMESS']),'id':sec['vmess_uuid'],'aid':'0','scy':'auto','net':'ws','type':'none','host':cfg['VMESS_HOST'],'path':sec['vmess_path'],'tls':'tls','sni':cfg['VMESS_HOST']}
    nodes.append('vmess://'+b64(json.dumps(vm,separators=(',',':'))))
    out=Path('/var/lib/vpn-subscription'); out.mkdir(parents=True,exist_ok=True)
    # Shadowrocket accepts URI list in base64 subscription form.
    (out/'shadowrocket.txt').write_text(b64('\n'.join(nodes))+'\n')
    # v2rayNG subset: VLESS REALITY, SS, Trojan and VMess.
    (out/'v2rayng.txt').write_text(b64('\n'.join([nodes[0],nodes[5],nodes[6],nodes[7]]))+'\n')
    # Mihomo YAML candidate profile.
    proxies=[
      {'name':'RackNerd VLESS REALITY','type':'vless','server':cfg['REALITY_HOST'],'port':int(cfg['PORT_REALITY']),'uuid':sec['vless_uuid'],'network':'tcp','tls':True,'servername':cfg['REALITY_SNI'],'client-fingerprint':'chrome','flow':'xtls-rprx-vision','reality-opts':{'public-key':sec['reality_public'],'short-id':sec['reality_short_id']}},
      {'name':'RackNerd VLESS XHTTP','type':'vless','server':cfg['XHTTP_HOST'],'port':int(cfg['PORT_XHTTP']),'uuid':sec['vless_uuid'],'network':'xhttp','tls':True,'servername':cfg['XHTTP_HOST'],'client-fingerprint':'chrome','xhttp-opts':{'path':sec['xhttp_path']}},
      {'name':'RackNerd AnyTLS','type':'anytls','server':cfg['ANYTLS_HOST'],'port':int(cfg['PORT_ANYTLS']),'password':sec['anytls_password'],'sni':cfg['ANYTLS_HOST']},
      {'name':'RackNerd Hysteria2','type':'hysteria2','server':cfg['HY2_HOST'],'port':int(cfg['PORT_HY2']),'password':sec['hy2_password'],'sni':cfg['HY2_HOST'],'alpn':['h3']},
      {'name':'RackNerd TUIC','type':'tuic','server':cfg['TUIC_HOST'],'port':int(cfg['PORT_TUIC']),'uuid':sec['tuic_uuid'],'password':sec['tuic_password'],'congestion-controller':'bbr','udp-relay-mode':'native','sni':cfg['TUIC_HOST'],'alpn':['h3']},
      {'name':'RackNerd Shadowsocks','type':'ss','server':cfg['SS_HOST'],'port':int(cfg['PORT_SS']),'cipher':'chacha20-ietf-poly1305','password':sec['ss_password']},
      {'name':'RackNerd Trojan TLS','type':'trojan','server':cfg['TROJAN_HOST'],'port':int(cfg['PORT_TROJAN']),'password':sec['trojan_password'],'sni':cfg['TROJAN_HOST'],'network':'tcp'},
      {'name':'RackNerd VMess WS TLS','type':'vmess','server':cfg['VMESS_HOST'],'port':int(cfg['PORT_VMESS']),'uuid':sec['vmess_uuid'],'alterId':0,'cipher':'auto','tls':True,'servername':cfg['VMESS_HOST'],'network':'ws','ws-opts':{'path':sec['vmess_path'],'headers':{'Host':cfg['VMESS_HOST']}}}
    ]
    import yaml
    (out/'mihomo.yaml').write_text(yaml.safe_dump({'mixed-port':7890,'allow-lan':False,'mode':'rule','log-level':'info','proxies':proxies,'proxy-groups':[{'name':'RackNerd','type':'select','proxies':[p['name'] for p in proxies]}],'rules':['MATCH,RackNerd']},sort_keys=False,allow_unicode=True))
    for f in out.iterdir(): f.chmod(0o640)
    # Nginx exact tokenized paths; no directory listing and no token in process arguments.
    token=sec['sub_token']
    urls=Path('/etc/vpn-deploy/secrets/subscription-urls.txt')
    urls.write_text('\n'.join([f"https://{cfg['SUB_HOST']}:{cfg['PORT_SUB']}/{token}/mihomo.yaml", f"https://{cfg['SUB_HOST']}:{cfg['PORT_SUB']}/{token}/shadowrocket.txt", f"https://{cfg['SUB_HOST']}:{cfg['PORT_SUB']}/{token}/v2rayng.txt"])+'\n')
    urls.chmod(0o600)
    nginx=f'''server {{
    listen 80;
    server_name {cfg['REALITY_HOST']} {cfg['XHTTP_HOST']} {cfg['ANYTLS_HOST']} {cfg['HY2_HOST']} {cfg['TUIC_HOST']} {cfg['SS_HOST']} {cfg['TROJAN_HOST']} {cfg['VMESS_HOST']} {cfg['WEB_HOST']} {cfg['SUB_HOST']};
    location ^~ /.well-known/acme-challenge/ {{ root /var/www/acme; default_type text/plain; }}
    location / {{ return 404; }}
}}
server {{ listen 127.0.0.1:{cfg['PORT_FALLBACK']}; server_name localhost; root /var/www/html; location / {{ try_files $uri $uri/ =404; }} }}
server {{
    listen {cfg['PORT_SUB']} ssl;
    server_name {cfg['SUB_HOST']};
    ssl_certificate {cert}; ssl_certificate_key {key};
    ssl_protocols TLSv1.2 TLSv1.3;
    location = /health {{ default_type text/plain; return 200 'ok'; }}
    location = /{token}/mihomo.yaml {{ alias /var/lib/vpn-subscription/mihomo.yaml; default_type text/yaml; }}
    location = /{token}/shadowrocket.txt {{ alias /var/lib/vpn-subscription/shadowrocket.txt; default_type text/plain; }}
    location = /{token}/v2rayng.txt {{ alias /var/lib/vpn-subscription/v2rayng.txt; default_type text/plain; }}
    location / {{ return 404; }}
}}
'''
    Path('/etc/nginx/sites-available/vpn-subscription').write_text(nginx)
    print('Generated Xray, sing-box, Nginx and three subscription profiles.')

if __name__ == '__main__': main()
