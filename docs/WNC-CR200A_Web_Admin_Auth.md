# WNC-CR200A — Web Administration Configs & Authentication

Where the web-administration configuration and authentication machinery lives in the
WNC-CR200A software stack, what each piece does, and — with special focus — **how login
and session management are implemented**. Sources: the official GPL release (tier A),
the shared-platform CR1000A public firmware dump + boot log (tier B), and the stock
OpenWrt 18.06 files of the same generation (tier C). Evidence copies:
`analysis/web_auth/`. Compiled 2026-10-25. Companion docs:
`docs/WNC-CR200A_Boot_Process_and_Services.md` (boot chain, service table),
`docs/Verizon_Gateway_Default_Credentials.md` (label credentials).

## 0. TL;DR

- The HTTP server is **lighttpd 1.4.65** (in the CR200A GPL release), started by the
  `S99zarc_lighttpd_luci` init unit. Its **device `lighttpd.conf` is not public** — it
  ships only in the withheld rootfs; the upstream reference config from the same
  tarball is the closest available baseline.
- Authentication is **not** done by the web server. The LuCI-derived UI talks JSON-RPC
  to **rpcd** over ubus; login is `session.login` in
  `rpcd-2019-12-10/session.c` (**verbatim in the CR200A GPL release**). Accounts come
  from **`/etc/config/rpcd`** (`config login` sections); passwords are `crypt()` hashes
  or a **`$p$<user>` pointer into `/etc/shadow`**. Rights come from
  **`/usr/share/rpcd/acl.d/*.json`** groups.
- **Session management** (all in `session.c`/`session.h`): 32-hex-char session IDs from
  `/dev/urandom`, **300 s sliding idle timeout** (re-armed on every RPC call), sessions
  persisted as files in `/var/run/rpcd/sessions`, an `unauthenticated` default session,
  and a freeze/thaw "apply session" that survives config-apply restarts.
- Login-adjacent scripts found: `dynamic_dns_lucihelper.sh` (DDNS credentials from uci,
  incl. `[USER:PASS@]` proxy), `99_10_failsafe_login` (**failsafe = passwordless root
  dropbear + console shell**), busybox example CGIs (no auth). TLS material lives in a
  dedicated **2 MB eMMC certificate partition (`/dev/mmcblk0p26`)** per the boot log.

## 1. Inventory of everything found

| File (evidence) | Tier | Role |
|---|---|---|
| `analysis/web_auth/session.c`, `session.h` — from `gpl_release/rpcd-2019-12-10-aaa08366.tar.xz` | A | **THE login + session implementation** (1,433 lines) |
| `analysis/web_auth/rpcd.config.openwrt-18.06` | C | Stock `/etc/config/rpcd` — the web-admin account config |
| `analysis/web_auth/luci-base.json.acl.d` | C | Stock `/usr/share/rpcd/acl.d/luci-base.json` (ACL group format) |
| `analysis/web_auth/mosquitto.conf.upstream-1.6.9` | C | MQTT broker config (anon-auth default) |
| `analysis/gpl_rootfs/raw/…/rpcd-mod-luci-20191114.tar.gz` → `src/luci.c` | A | `luci-rpc` ubus object (UI data API behind the session) |
| `analysis/gpl_rootfs/unpacked/lighttpd-1.4.65/…/doc/config/lighttpd.conf` + `conf.d/{cgi,fastcgi,scgi}.conf` | A | Upstream lighttpd reference configs (mod_cgi wiring) |
| `analysis/gpl_rootfs/unpacked/ddns-scripts/…/dynamic_dns_lucihelper.sh` (+ `dynamic_dns_functions.sh`) | A | Script handling DDNS **credentials** from uci |
| `analysis/cr1000a_rootfs/lib/preinit/99_10_failsafe_login` | B | Failsafe auth bypass (dropbear + root shell) |
| `analysis/cr1000a_rootfs/etc/passwd`, `bin_listing.txt` (`login`, `login.sh`) | B | Console accounts / login helpers |
| `analysis/gpl_rootfs/unpacked/shadow-4.8.1/…/etc/pam.d/passwd` | A | PAM stack for `passwd` changes (upstream) |
| `analysis/gpl_rootfs/unpacked/busybox-1.30.1/…/networking/httpd_post_upload.cgi` | A | Example upload CGI — **no auth** (example only) |
| `analysis/gpl_rootfs/unpacked/sscep/sscep/files/sscep.config` | A | SCEP enrollment state (no credentials) |
| Boot log lines (`downloads/cr1000a-dump/BootLogs/cr1000a_boot.log`) | B | `S12rpcd`, `S99zarc_lighttpd_luci`, cert partition |

Not found anywhere public (see §6): the device's own `lighttpd.conf`, `/etc/config/rpcd`,
`acl.d` JSONs, LuCI `dispatcher`/login JS, and `/etc/shadow`.

## 2. Web server configuration (lighttpd)

- **Version 1.4.65** — `gpl_release/lighttpd-1.4.65.tar.xz` (tier A), started by
  `S99zarc_lighttpd_luci` (tier B boot log). No `uhttpd`, no busybox-httpd in the
  service set — busybox's `httpd` source and its example CGIs (`httpd_indexcgi.c`,
  `httpd_post_upload.cgi`) ship in the GPL release but nothing starts them.
- Upstream reference `doc/config/lighttpd.conf` (tier A, committed):
  `server.port = 80`, `server.username/groupname = "lighttpd"`, document-root
  `…/htdocs`, `include conf_dir + "/modules.conf"`, CGI via `conf.d/cgi.conf`
  (`server.modules += ("mod_cgi")`, `cgi.assign`), plus `fastcgi.conf`/`scgi.conf`
  variants. The Verizon-manual-visible behavior layers on top:
  - **HTTPS with a self-signed certificate** (manuals instruct users to click through
    "connection is not private" to `https://192.168.1.1`) → `mod_openssl` + cert files.
  - TLS material store: boot log `certificate locate at /dev/mmcblk0p26, total size is
    2048 KB` — a dedicated **2 MB certificate partition** on eMMC (also referenced by
    the ARC cloud client, `AllowSelfSigned` vendor flag = 0).
  - Host handling for `mynetworksettings.com` (LAN DNS rebind by dnsmasq).
  - UI entry is a LuCI-style CGI/rpcd endpoint (see §3) rather than static auth files —
    no `.htpasswd`-style file exists in any artifact; auth is application-level.

## 3. Authentication mechanism (rpcd `session.login`)

Login is implemented in **`session.c`** (`rpc_handle_login`, ubus object
`luci-rpc-session`, method `login`) — quoted essentials:

**Account store** — uci package `rpcd` (`/etc/config/rpcd`), `config login` sections.
Stock OpenWrt 18.06 (tier C, `analysis/web_auth/rpcd.config.openwrt-18.06`):

```
config rpcd
	option socket /var/run/ubus.sock
	option timeout 30

config login
	option username 'root'
	option password '$p$root'
	list read '*'
	list write '*'
```

**Password check** (`rpc_login_test_password`):
1. Hash empty, `"!"`, or `"x"` → **login succeeds with any password** (code comment:
   "password is not set").
2. Hash starts with `$p$` → look up that username in **`/etc/shadow`** (`getspnam`) or
   `/etc/passwd`, and check against *its* hash (this is how the stock config points at
   `root`'s shadow entry).
3. Otherwise compare `crypt(password, hash)` — i.e. whatever `crypt(3)` scheme the hash
   uses (sha512crypt on modern shadow).

**Rights** (`rpc_login_setup_acl_file`): after login, the `read`/`write` group lists of
the login section are matched (with `!`-negation globs) against every JSON file in
**`/usr/share/rpcd/acl.d/`**; matching groups' `{read,write: {scope: [object→functions]}}`
grants are compiled into the session. `write` implies `read`. The `unauthenticated`
group is what the all-zero **default session** gets — that is the pre-login API surface
(e.g. the login call itself, board info).

`rpcd-mod-luci` (`luci.c`, tier A) then exposes the UI's data plane as `luci-rpc`
(`getNetworkDevices`, `getWirelessDevices`, `getHostHints`, `getDUIDHints`,
`getBoardJSON`, `getDSLStatus`, `getDHCPLeases`) — every call is gated by
`rpc_session_access(sid, …)`.

## 4. Session management (deep dive)

From `session.h` (verbatim constants):

```c
#define RPC_SID_LEN                    32
#define RPC_DEFAULT_SESSION_TIMEOUT    300
#define RPC_DEFAULT_SESSION_ID         "00000000000000000000000000000000"
#define RPC_SESSION_DIRECTORY          "/var/run/rpcd/sessions"
#define RPC_SESSION_ACL_DIR            "/usr/share/rpcd/acl.d"
```

- **Session ID**: 32 hex chars read from **`/dev/urandom`** (`rpc_random`). Returned to
  the UI as `sid`; subsequent ubus/HTTP calls present it (cookie or request param — the
  LuCI frontend that sets the cookie is in the withheld layer).
- **Idle timeout**: default **300 s**, per-login overridable (`timeout` field).
  `rpc_touch_session()` re-arms the uloop timer **on every access** — a sliding window;
  expiry destroys the session and its ACL data.
- **Storage**: in-memory AVL tree **plus one file per session** under
  `/var/run/rpcd/sessions/` (tmpfs — gone on reboot). `session.list/get/set/unset`
  manage per-session key/value data (the UI stores e.g. username there).
- **Default session**: constant all-zero `sid`, created at startup with only the
  `unauthenticated` ACLs; `session.destroy` on it is denied.
- **Apply-session reclaim**: `rpc_freeze()` writes sessions to disk; `rpc_thaw()` +
  `rpc_reclaim_apply_session(username)` restore a frozen session across an rpcd restart
  *only if the username matches* — this keeps admins logged in across "Save & Apply".
- **ACL evaluation** (`rpc_session_access`): scope/object/function triple checked
  against the compiled grants with `fnmatch` patterns.

## 5. Scripts that handle login / credentials

| Script | What it does with credentials |
|---|---|
| `session.c` `rpc_handle_login` | The web login path (§3) — username/password → sid |
| `dynamic_dns_lucihelper.sh` + `dynamic_dns_functions.sh` (tier A, ddns-scripts) | Reads DDNS provider **username/password from `/etc/config/ddns`** (uci plaintext) and supports `-p [USER:PASS@]PROXY:PORT`; used by the LuCI DDNS screen |
| `99_10_failsafe_login` (tier B) | Failsafe mode: `dropbearkey` → **dropbear with an ephemeral key and no password**, plus `ash --login` on console — full root by design for recovery |
| `login` / `login.sh` in initramfs `bin/` (tier B) | Console login against `/etc/passwd` (`root:x:0:0` = shadow-passthrough) |
| `shadow-4.8.1/etc/pam.d/passwd` (tier A) | Upstream PAM stack for password changes |
| `httpd_post_upload.cgi` (tier A, busybox examples/) | Example multipart upload CGI with **no authentication** — examples only, not started |

Peripheral auth surfaces: **OpenSSH 7.9p1** in the GPL release (started by `S22arc_sshd`
on the shared platform); **mosquitto 1.6.9** with stock config
`#allow_anonymous true` — i.e. **anonymous MQTT by default** unless Verizon overrides
(`analysis/web_auth/mosquitto.conf.upstream-1.6.9` line 651); TR-069 (`S22arc_tr69`)
carries its own ACS credentials in the withheld layer.

## 6. What is still hidden, and how to get it

The definitive files — `/etc/lighttpd/*`, `/etc/config/rpcd`, `/usr/share/rpcd/acl.d/*`,
LuCI's `dispatcher`/login JS, `/etc/shadow` — exist only in the **LUKS-encrypted main
rootfs** (no public CR200A image; GPL release ships sources only). To close the gap:

1. Extract a real image with the lab tooling (`scripts/binwalk_extract_rootfs.sh`,
   `docs/Firmware_Analysis_Lab_Setup.md`); if LUKS-encrypted, the key material path
   documented in the community research applies to the shared platform, or
2. On a live device: `cat /etc/config/rpcd /usr/share/rpcd/acl.d/*.json
   /etc/lighttpd/lighttpd.conf` over the UART/admin shell (JA1 header — lab doc §5).

## 7. Auth observations (for the security review)

1. **Empty password hashes accept any password** (`rpc_login_test_password`) — verify
   no login section ships with `password ''`/`!`.
2. `$p$root` → `/etc/shadow` means the **web password is the OS root password** in the
   stock layout; on CR200A the label password (per the credentials doc) should be that
   hash's input.
3. Session SIDs are 128-bit urandom, 300 s sliding expiry — reasonable; sessions in
   tmpfs survive process restart (apply) but not reboot.
4. **Failsafe mode = unauthenticated root** (dropbear + console shell) — physical/power
   access wins; standard OpenWrt behavior, worth knowing for threat modeling.
5. DDNS/proxy credentials sit **plaintext in uci** (`/etc/config/ddns`).
6. MQTT `allow_anonymous` default — check the live `mosquitto.conf`.
7. The cert partition `/dev/mmcblk0p26` (2 MB) is the trust/identity store — of interest
   for anyone auditing the self-signed HTTPS cert generation.
