# WNC-CR200A — Hidden Debug Surfaces & Debug-Shell Enablement

Hunt for hidden URLs (`/debug.cgi`, `/diag.html`-class paths), undocumented API
endpoints, and paths to a **debug shell** on the Verizon WNC-CR200A / shared VZSDK
platform. Sources: firmware artifacts in this repo (initramfs rootfs, GPL release,
boot log), community research (OpenWrt CR1000A thread, r/Fios), and the
`scripts/web_audit/` enumeration kit for the live device. Authorized testing of the
owner's gateway. Compiled 2026-10-25. Companions:
`docs/WNC-CR200A_Web_Vulnerability_Audit.md` (attack surface), 
`docs/WNC-CR200A_Boot_Process_and_Services.md` (boot chain),
`docs/Firmware_Analysis_Lab_Setup.md` (UART/JA1).

## 0. TL;DR

- The admin UI is a **hash-routed SPA** — hidden pages are `/#/…` routes, not separate
  files. Community-confirmed: **`/cgi/cgi_basic.js`** (debug page: CPU temp, connected
  device counts, "internal undocumented Verizon stuff"), **`/#/firmware_upgrade`**
  (manual image sideload), **`/#/zenreach_ap`** (guest-WiFi vendor integration).
- The firmware ships a **`/cgi/` directory** and a telnetd/inetd/tftpd trio plus
  debug daemons (`sysdebug`, `ftm`, `diag_socket_app`) and vendor services
  (`S90arc_appapi`, `S98arc_lcmd`, `S75install_mode`, `S13debug`, `S10cosmos`) — the
  prime candidates for undocumented web/API endpoints and shell toggles.
- **Debug-shell enablement** is most plausible via (a) the UART console (JA1) with
  U-Boot + the preinit **`f`-key failsafe** (passwordless root dropbear!) and
  **`[1]-[4]` debug-level** selector writing `/tmp/debug_level`, (b) LUKS-decrypt
  failure which drops to `ash --login`, or (c) a hidden web/TR-069 toggle for
  telnetd/ssh (community precedent: FIOS-G1100 TR-069 SSH enable).

## 1. Hidden web routes (community-confirmed)

| Route | What it is | Source |
|---|---|---|
| `https://192.168.1.1/cgi/cgi_basic.js` | **Debug page** — CPU temperature, connected-device counts, internal/undocumented Verizon data | r/Fios "Hidden Menu on Router" (2023-02) |
| `https://192.168.1.1/#/firmware_upgrade` | **Manual firmware upgrade** (hidden from menus) — accepts an image file for sideload | r/Fios threads; used for manual updates |
| `https://192.168.1.1/#/zenreach_ap` | Hidden SPA page for the Zenreach guest-WiFi/AP integration ("no new ports opened when enabled") | OpenWrt CR1000A thread (tesf23, 2023-02) |

The `/cgi/` directory (sibling of `/cgi-bin/`) is nonstandard and debug-oriented —
enumerate it fully (`cgi_*.js` files are likely additional debug screens: expect
`cgi_status`, `cgi_diag`, `cgi_ftm`-class siblings). SPA route enumeration = download
the JS bundles from `/` and extract `#/…` route strings and `ubus` call names (the
enumerator script automates this).

## 2. Firmware-derived candidates (static evidence)

From the boot log service list, initramfs binaries (`analysis/cr1000a_rootfs/`,
re-extractable with `scripts/extract_cpio.py`), and GPL release:

| Name | Evidence | Debug relevance |
|---|---|---|
| `S90arc_appapi` | init unit (boot log) | **Vendor "app API"** — the most likely undocumented HTTP/JSON API (used by the My Verizon app?) |
| `S98arc_lcmd` | init unit | "lcmd" = local-command service — shell-ish by name |
| `S75install_mode`, `S08boot-ftm`/`S97ftm`, `ftm` | init units + `usr/sbin/ftm` | **Factory test mode** (Qualcomm tcmd/diag) — classic hidden debug entry |
| `S13debug`, `S98diag_socket_app`, `diag_socket_app` | init units + binary (`diag_socket_log -a <ip> -p <port>`) | network diagnostics daemon |
| `S10cosmos` | init unit (`****** START COSMOS ******`, `/data/db`) | device database service |
| `sysdebug` (`sbin/`) | script: sources `/lib/debug/<pkg>` helpers, **`eval "$@"`** | **package debug dispatcher** — `/lib/debug/*` content is the debug-script surface (aqr113c seen in logs) |
| `dashboard.sh` (`usr/sbin/`, Qualcomm 2019) | system dump CLI: `/proc/cmdline`, JTAG ID via `devmem`, TZ log, Q6 watchdog, `ubus call system watchdog`, opkg/lsmod | likely backend for a status/debug page |
| `telnetd`, `inetd`, `tftpd` | `usr/sbin/` | **shell/file servers** — if any web/TR-069 toggle enables these, that is the debug shell |
| `/cgi/…` (SPA + cgi dir) | community (§1) | hidden debug UI |

Earlier artifact greps for `/debug.cgi`, `/diag.html` etc. found only lighttpd test-suite
fixtures (`/tiny-fcgi.cgi`, `/upd.php`, `/get-server-env.php`, `/cmdline` — in
`lighttpd-1.4.65/tests/`, **not** device code) — do not chase those.

## 3. Debug-shell enablement paths (ranked)

1. **UART / JA1 console (most direct — lab doc §5).** Boot log shows an interactive
   U-Boot (`IPQ807x# setenv …; tftpboot uImage-cr1000a.bin; bootm` — the dumper booted
   over TFTP!). Preinit hooks (`analysis/cr1000a_rootfs/lib/preinit/`):
   - `f` key during "Press the [f] key … to enter failsafe mode" → failsafe →
     `99_10_failsafe_login`: **dropbear root SSH with an ephemeral key (no password)**
     + `ash --login` on console. Also forced by `failsafe=1` on the kernel cmdline
     (U-Boot `setenv bootargs …`).
   - Keys **`[1] [2] [3] [4]`** → "select the debug level" → written to
     **`/tmp/debug_level`** (`30_failsafe_wait`) — consumed by withheld init code
     (likely log verbosity / debug service activation). Experiment: boot with each
     level and diff listening ports (`netstat -lntup`) + `logread`.
   - LUKS decrypt failure in `80_mount_root` → **`ash --login`** root shell fallback.
2. **Hidden web pages (§1).** `/cgi/cgi_basic.js` is itself a debug UI; the hidden
   `/#/firmware_upgrade` accepts images (secure boot: U-Boot carries x509 chain —
   modified images likely rejected without key material). `/cgi/` may hold further
   debug screens (enumerate). `/#/zenreach_ap`-class SPA routes: extract all routes
   from the JS bundles.
3. **Undocumented API = `/ubus` object enumeration.** With an admin session, call
   ubus `list` (JSON-RPC `list` method) and inventory every object — vendor objects
   (`arc_*`, `zarc_*`, `luci-rpc`, `file`) are the undocumented API surface;
   `file exec` (audit doc V-04) is a shell-equivalent where ACLs permit.
4. **TR-069 / ACS** (WAN-side management, `S22arc_tr69`): community precedent —
   FIOS-G1100 research enabled SSH via TR-069 (see `ozwaldorf/FIOS-G1100`,
   gorgias.me G1100 writeup); the CR1000A thread proposes the same. Only test with
   your own ACS — never against Verizon infrastructure.
5. **Service toggles via uci/`file exec`** — `telnetd`/`tftpd` are present: if a hidden
   page or `init.d` invocation starts `telnetd`, that's the debug shell on :23.

## 4. Cryptographic note (affects image sideloading)

`80_mount_root` (verbatim in `analysis/cr1000a_rootfs/lib/preinit/`) shows the A/B
rootfs is **LUKS-encrypted** (`rootfs`/`rootfs_1` PARTLABELs) and decrypted with
**`/etc/keyfile` from the initramfs** — which is *inside the public firmware dump*
(recover with `scripts/extract_cpio.py`; key bytes deliberately not copied into this
repo). Any full firmware image for the family can therefore be decrypted offline once
obtained — the missing piece remains a full image (OTA-only distribution).

## 5. Live enumeration kit

```bash
# lab VM, owner's device:
scripts/web_audit/enum_hidden_endpoints.sh https://192.168.1.1
```
The script: (1) pulls the SPA shell + JS bundles and extracts `#/` routes, `/cgi/*`
names, and ubus method strings; (2) probes `scripts/web_audit/hidden_paths.txt`
(status-code diff); (3) lists `/ubus` objects with an admin session; (4) checks
telnet/tftp ports 21/23/69/2323. Save output to `logs/web-audit/`.

## 6. What is not public

The web root itself (`/www`, `/cgi/`, lighttpd vhosts) lives in the LUKS rootfs.
Until a full image is obtained or a device shell is available, route names beyond §1
remain hypotheses (§2). The enumerator's JS-extraction step is the fastest way to
grow the list on the live box.
