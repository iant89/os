# Burp Suite checklist — WNC-CR200A admin interface (authorized, owner's device)

## Scope & proxy
- [ ] Lab VM NIC on the gateway LAN; browser proxy `127.0.0.1:8080`
- [ ] Target scope: `https://192.168.1.1/*`, `https://mynetworksettings.com/*`
- [ ] Accept the self-signed cert (note TLS findings as V-09)
- [ ] Session handling: "Cookie-based session", 300 s sliding-window awareness

## Manual / Repeater — per endpoint
- [ ] Login (`session.login` / login form): V-05 probes — password `""`, `!`, `x`,
      `admin`; user `root`/`admin`; response-timing lockout check
- [ ] `/ubus` JSON-RPC with `sid=000…0`: enumerate `session list`, `file read/exec`,
      `uci get`, `luci-rpc *` (V-06)
- [ ] Diagnostics ping/traceroute/nslookup: `;id`, `|id`, `$(id)`, backticks,
      `%0a` newline, argv-only abuse (`-f`, `--version`), 64 KB input (V-01/V-04)
- [ ] Firmware upgrade POST + `cgi-upload`: filename `../` traversal, `/etc/crontabs/root`
      as target, double-encoded `..`, oversized/invalid image (V-02 class)
- [ ] Backup download / `cgi-download`: `<allowed>/../../../../etc/shadow` chain (V-02)
- [ ] DDNS form: quote breakout `'`, `"` in username/password/url/server, `$(...)`,
      `ip_script` path (V-03)
- [ ] QoS/limits forms: same injection set
- [ ] Wi-Fi/SSID/PSK + hostname fields: stored XSS, hostapd config injection

## Scanner
- [ ] Active scan on all in-scope requests; increase "Command injection" and
      "Path traversal" insertion points; scan both GET and JSON POST bodies
- [ ] Intruder: fuzz `sid`, `filename`, `path`, `command`, `params` positions
- [ ] CSRF PoC generator on every state-changing request (login-adjacent too)
- [ ] Session-token analysis: entropy, rotation on login, fixation

## Evidence & reporting
- [ ] Save all items (Project → export) to `logs/web-audit/`
- [ ] Map results to finding IDs in `docs/WNC-CR200A_Web_Vulnerability_Audit.md`
