# Verizon Internet Gateway (`WNC-CR200A`) — Open Source Firmware Package & Components

This repository contains the open-source software manifest, download & extraction tooling, and pinned core OpenWrt firmware components for the **Verizon Internet Gateway (`WNC-CR200A`)** (Qualcomm Dragonwing NPro 6E + Snapdragon X65 5G Modem-RF platform, manufactured by Wistron NeWeb Corporation).

---

## 1. Official Verizon Open Source Portal Links

Verizon publishes the official GPL source package and open-source software disclosures for the **WNC-CR200A** on the [Verizon Free and Open Source Software Portal](https://www.verizon.com/support/residential/internet/equipment/open-source-software):

| Artifact | Release | Direct Download URL |
| :--- | :--- | :--- |
| **WNC-CR200A GPL Source Package (`.zip`)** | `3.2.0.13` | [`WNC-CR200A_gpl_release_3.2.0.13.zip`](https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/WNC-CR200A_gpl_release_3.2.0.13.zip) |
| **WNC-CR200A Open Source Disclosure (`.pdf`)** | `3.2.0.13` | [`WNC-CR200A_Open_Source_Resource_3.2.0.13.pdf`](https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/WNC-CR200A_Open_Source_Resource_3.2.0.13.pdf) |
| **VZSDK Container Open Source Disclosure (`.pdf`)** | `VZSDK` | [`Verizon-Fios-Router-(G3100-CR1000A-CR1000B)-additional-open-source-disclosures-for-VZSDK-Container.pdf`](https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/Verizon-Fios-Router-(G3100-CR1000A-CR1000B)-additional-open-source-disclosures-for-VZSDK-Container.pdf) |

---

## 2. Quick Start: Downloading & Extracting the Full GPL Release

To download the full `WNC-CR200A_gpl_release_3.2.0.13.zip` archive and disclosure PDFs from Verizon's Open Source Portal and extract the source tree into `src/gpl_release_3.2.0.13/`:

```bash
./scripts/download_wnc_cr200a_gpl.sh
```

Or manually via `curl`:

```bash
mkdir -p downloads src/gpl_release_3.2.0.13
curl -fL -C - \
  -A "Mozilla/5.0" \
  -e "https://www.verizon.com/support/residential/internet/equipment/open-source-software" \
  -o downloads/WNC-CR200A_gpl_release_3.2.0.13.zip \
  "https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/WNC-CR200A_gpl_release_3.2.0.13.zip"

unzip -q downloads/WNC-CR200A_gpl_release_3.2.0.13.zip -d src/gpl_release_3.2.0.13
```

---

## 3. Repository Structure & Included Firmware Components

Because the cloud agent sandbox restricts outbound shell access to `github.com` (and blocks direct large binary downloads from `verizon.com`), this repository includes:

1. **`manifest/wnc-cr200a-open-source-packages.json`**
   Machine-readable manifest of the WNC-CR200A `3.2.0.13` firmware components, versions, licenses, and upstream URLs extracted from Verizon's official disclosure PDF.
2. **`docs/WNC-CR200A_Open_Source_Disclosure.md`**
   Complete hardware/firmware architecture summary and component reference table for the WNC-CR200A.
3. **`scripts/download_wnc_cr200a_gpl.sh`**
   Automated downloader and extractor for Verizon's official `WNC-CR200A_gpl_release_3.2.0.13.zip` package.
4. **`scripts/fetch_github_components.sh` & `src/components/`**
   Pre-fetched OpenWrt 18.06 and userspace firmware components pinned to the exact dates/revisions specified in the WNC-CR200A `3.2.0.13` disclosure:
   - `src/components/cgi-io` (`v19`, commit `03ab4b3c76e2`)
   - `src/components/fstools` (`2020-05-12`, commit `84269037b75d`)
   - `src/components/fwtool` (`v2`, commit `8f7fe925ca20`)
   - `src/components/jsonfilter` (`2018-02-04`, commit `c7e938d6582a`)
   - `src/components/libiwinfo` (`2019-10-16`, commit `07315b6fdb25`)
   - `src/components/libnl-tiny` (`0.1`, commit `0219008cc876`)
   - `src/components/librpc` (`2015-11-04`, commit `a921e3ded051`)
   - `src/components/libubox` (`2020-05-25`, commit `86818eaa976b`)
   - `src/components/mcproxy` (`2017-08-24`, commit `93b5ace42268`)
   - `src/components/netifd` (`2019-08-05`, commit `5e02f94411b0`)
   - `src/components/opkg-lede` (`0.4.2`, commit `f2166a89b7e9`)

---

## 4. FCC ID Documentation (NKR-LV65C-T3)

The repository also carries the official FCC **Internal Photos** exhibit for the same
device (FCC ID `NKR-LV65C-T3`, Wistron NeWeb):

- **`downloads/fcc/WNC-CR200A_FCC_Internal_Photos_6604463.pdf`** — "22A0288R-Product
  Photos" (DEKRA, 33 pages), SHA-256
  `b4f60559d2e1097f23e2b56d53b879bbf340f1e503dfd9cd9636b6faea7d7b48`.
- **`docs/WNC-CR200A_FCC_Internal_Photos_Analysis.md`** — chip identification (SoC,
  flash, DRAM, modem, Wi-Fi 6E front end) and the UART/JTAG test-point survey derived
  from the photos.
- **`.github/workflows/fetch-fcc-exhibits.yml`** — re-downloads the exhibit from 5 mirrors,
  verifies the hash, and commits the PDF to this branch.

---

## 5. Verizon Gateway Default Credentials Survey

- **`docs/Verizon_Gateway_Default_Credentials.md`** — publicly documented default
  credentials for Verizon gateways/routers (5G/LTE Home, Fios, DSL, Jetpack). Key point:
  modern units such as the WNC-CR200A ship with a **unique per-device password printed
  on the device label**, not a shared default like `admin`; shared `admin`/`password`
  style defaults exist only on legacy Actiontec/Westell hardware (and one documented
  ASK-NCQ1338 exception).

---

## 6. Rootfs Extraction, Boot Process & Services

- **`docs/WNC-CR200A_Boot_Process_and_Services.md`** — binwalk-based rootfs extraction
  and analysis of the boot chain, `/etc/init.d/` service set (107 units from a real boot
  log), and the lighttpd/LuCI/rpcd web server stack. Evidence lives in
  `analysis/gpl_rootfs/` (CR200A GPL release extraction), `analysis/cr1000a_rootfs/`
  (initramfs boot files + service order), and `analysis/openwrt-18.06-baseline/`
  (upstream init framework).
- **`scripts/binwalk_extract_rootfs.sh`** + **`scripts/extract_cpio.py`** — reusable
  tooling: carve and unpack root filesystems (squashfs/cpio) from any firmware image and
  collect init scripts and web configs.
- **`.github/workflows/fetch-gpl-rootfs.yml`** — downloads Verizon's GPL release from an
  environment that can reach verizon.com, unpacks all 152 source tarballs, runs binwalk,
  and commits the init.d/web-config evidence to this branch.

---

## 7. Firmware Analysis Lab (local, offline VM + UART)

- **`docs/Firmware_Analysis_Lab_Setup.md`** — build an air-gap-capable analysis
  environment: Linux VM (Vagrant/VirtualBox or QEMU/KVM) provisioned with binwalk,
  unblob, jefferson, ubi-reader, yaffshiv, sasquatch, firmware-mod-kit and Ghidra 12.2;
  plus a complete UART-to-USB runbook (CP2102/FT232 wiring to the JA1 header, logic-level
  safety, boot-console capture).
- **`manifest/firmware-lab-tools.json`** — every tool pinned to an exact version/commit
  with SHA-256; **`scripts/build_firmware_lab_bundle.sh`** collects them (plus pip/apt
  closures) for offline install via **`scripts/setup_firmware_lab.sh --bundle`**.
- **`scripts/uart_connect.sh`** / **`scripts/uart_boot_capture.sh`** + **`udev/`** rules —
  serial console access and boot-log capture for the device under test.

---

## 8. Web Administration & Authentication Analysis

- **`docs/WNC-CR200A_Web_Admin_Auth.md`** — inventory of web-admin configuration files
  (lighttpd, `/etc/config/rpcd`, rpcd `acl.d`) and a deep dive into login and session
  management (rpcd `session.login`: shadow-hash passwords, 32-hex `/dev/urandom`
  session IDs, 300 s sliding timeout, `/var/run/rpcd/sessions`), plus the credential
  handling scripts (DDNS helper, failsafe dropbear) and auth-review observations.
- **`analysis/web_auth/`** — evidence copies: rpcd `session.c`/`session.h` (from the
  CR200A GPL release), stock OpenWrt 18.06 `rpcd.config` and `luci-base.json` ACL,
  mosquitto 1.6.9 stock config.

---

## 9. Web Interface Vulnerability Audit

- **`docs/WNC-CR200A_Web_Vulnerability_Audit.md`** — audit of the admin web interface
  for command injection, authentication bypass, and path traversal, focused on
  diagnostics/ping, firmware-upgrade, DDNS, and login endpoints. Findings are backed by
  the rpcd/shell source shipped in the GPL release (e.g. DDNS `eval` command injection,
  `file exec` arbitrary execution, empty-hash login bypass) plus known-issue classes to
  verify live (LuCI CVE-2019-12272, cgi-io GHSA-jw5r-xhf5-2xcq).
- **`scripts/web_audit/`** — ready-to-run interception kit: OWASP ZAP Automation
  Framework plan, Burp Suite checklist, and `probe_auth_bypass.sh` (curl-based /ubus
  auth-bypass and traversal probes) for the lab VM against the live device.

## 10. Hidden debug endpoints & debug-shell enablement

[`docs/WNC-CR200A_Hidden_Debug_Endpoints.md`](docs/WNC-CR200A_Hidden_Debug_Endpoints.md)
inventories hidden URLs and undocumented APIs, and maps every plausible debug-shell
enablement path:

- **Community-confirmed hidden pages**: `/cgi/cgi_basic.js` (debug page: CPU temp,
  device counts), `/#/firmware_upgrade` (manual image sideload), `/#/zenreach_ap` —
  the admin UI is a hash-routed SPA, so hidden pages are `#/` routes and `/cgi/` files.
- **Firmware-derived candidates**: `arc_appapi`/`arc_lcmd` vendor services,
  `ftm` factory-test mode, `diag_socket_app`, `sysdebug` (`/lib/debug/*` dispatcher
  with `eval`), `telnetd`/`inetd`/`tftpd`.
- **Debug shells**: UART (JA1) + preinit `f`-key failsafe (passwordless root dropbear)
  and `[1]-[4]` debug-level selector (`/tmp/debug_level`); LUKS-decrypt failure →
  `ash --login`; hidden `/#/firmware_upgrade`; TR-069 SSH-enable precedent.
- **Enumeration kit**: `scripts/web_audit/enum_hidden_endpoints.sh` +
  `scripts/web_audit/hidden_paths.txt` (SPA route extraction from JS bundles, path
  probing, `/ubus` object inventory, telnet/tftp port check).

## 11. Configuration backup cryptography

[`docs/WNC-CR200A_Config_Backup_Crypto.md`](docs/WNC-CR200A_Config_Backup_Crypto.md)
specifies the Save & Restore `.cfg` format and documents a working decryption
method (verified against a real CR1000A fw-3.1.0.21 backup in this repo):

- **Format**: AES-256-CBC tar archive, per-file IV appended at end of file; the
  AES key is wrapped under a **constant firmware key** (public constants), i.e.
  obfuscation rather than confidentiality — any stolen backup is decryptable.
- **Integrity is non-functional**: the `backup_md5` tar member is written and
  accepted as the empty-file MD5 stub by the firmware itself; no MAC exists, so
  restored backups are unauthenticated input (device binding is logic-only).
- **Plaintext inventory**: 30-file uci config tree (rpcd login hashes, httpd,
  wireless PSKs, DDNS creds, `hal` model binding) + 3 SQLite state DBs
  (`.db`, `.cosmos_db`, `.oie_db`) — backups are secret stores.
- **Tooling**: `scripts/config_crypto/cfg_backup_tool.py` (`info`/`decrypt`/
  `inspect`, secrets redacted) — inspection-only by design; attempt record in
  `analysis/config_crypto/decrypt_attempt_CR1000A_V3.1.0.21.txt`.
