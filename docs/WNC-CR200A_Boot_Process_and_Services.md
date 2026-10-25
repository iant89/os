# WNC-CR200A — Rootfs Extraction, Boot Process & Services

Analysis of the **boot chain, `/etc/init.d/` service framework, and web server
configuration** of the Verizon Internet Gateway WNC-CR200A, produced by extracting
root filesystems with **binwalk** from the official open-source package and from a
publicly dumped sibling firmware image. Compiled 2026-10-25.

## 0. TL;DR

- The official **GPL release 3.2.0.13** (`WNC-CR200A_gpl_release_3.2.0.13.zip`,
  172,268,287 bytes, SHA-256 `4906a5aaddf275784f569e0a6eb80e0de18fe8f819a57af679b9e2d1c3651cbe`)
  contains **152 upstream source tarballs and no firmware/rootfs image** — binwalk finds
  no squashfs/jffs2/cpio payload anywhere in it. Verizon distributes CR200A firmware
  **OTA only** (no public image; both `verizon.com` and `cpe-ems34.verizon.com` firmware
  URL patterns probed and unreachable/absent).
- A public firmware dump of the **shared-platform sibling** (Verizon Router CR1000A,
  same Qualcomm IPQ807x + Verizon VZSDK stack — the two devices share one OSS
  disclosure) yields extractable kernels: binwalk carves a **656-entry initramfs root
  filesystem** and the device's real boot log enumerates **107 `/etc/init.d` services**,
  including the web server unit **`S99zarc_lighttpd_luci`**.
- The CR200A's own GPL release authenticates the software stack: **OpenWrt 18.06
  (procd/ubus/uci/netifd)** host + **lighttpd 1.4.65** web server + **rpcd/cgi-io**
  (LuCI-style web GUI backend) + **LXC 2.1.1 VZSDK container**, mosquitto, openssh,
  syslog-ng, dnsmasq/unbound, miniupnpd, avahi, lldpd, and more. Three genuine
  `/etc/init.d` scripts ship inside its tarballs (`ddns`, `qos`, `urandom_seed`).
- Boot chain: **PBL → Qualcomm XBL/SBL → U-Boot 2018.03 (secure boot) → ARM64 Linux
  kernel (4.4.60-class) + embedded initramfs → `/etc/preinit` → procd → `rcS
  /etc/rc.d/S*`**. The main root filesystem is **LUKS-encrypted squashfs** (LVM:
  `S15lvm2`, `cryptsetup`) and is not publicly decryptable/dumpable.

Everything below is tied to artifacts in this repo: `analysis/gpl_rootfs/` (CR200A GPL
extraction, committed by `.github/workflows/fetch-gpl-rootfs.yml`), `analysis/cr1000a_rootfs/`
(initramfs boot files + service order), `analysis/openwrt-18.06-baseline/` (upstream init
framework), and `scripts/binwalk_extract_rootfs.sh` + `scripts/extract_cpio.py` (tooling).

---

## 1. Method & evidence tiers

| Tier | Source | Status |
|---|---|---|
| **A — authentic CR200A** | `WNC-CR200A_gpl_release_3.2.0.13.zip` from Verizon's OSS portal (downloaded via the GitHub Actions fetch workflow; `analysis/gpl_rootfs/logs/`) | Component list, init-script samples, web stack, binwalk negative results |
| **B — shared platform** | Public dump `MeisterLone/Verizon-CR1000A` (GitHub) — CR1000A stock kernel + initramfs + boot log; same IPQ807x/VZSDK platform, same OSS disclosure document | Boot chain, `/etc/preinit` framework, full `/etc/rc.d` service order, service account list |
| **C — upstream baseline** | `openwrt/openwrt` branch `openwrt-18.06` (`analysis/openwrt-18.06-baseline/`): `rc.common`, `init.d/boot`, `init.d/network`, `init.d/dnsmasq`, `init.d/dropbear`, `init.d/uhttpd` | Semantics of the init framework the firmware uses |

CR200A-specific *names* of `/etc/rc.d` units (WNC prefixes replace the CR1000A's
`arc_*` names) are **not** in any public artifact; the service *set* is recoverable from
the GPL release and the shared platform evidence. See §7.

## 2. Rootfs extraction with binwalk

### 2.1 The open-source package (tier A)

```
binwalk WNC-CR200A_gpl_release_3.2.0.13.zip   → zip container (152 members, gpl_release/*.tar*)
binwalk <each of the 152 tarballs>            → gzip/xz/bzip2 source archives only
binwalk <largest 80 non-source blobs inside>  → no squashfs / jffs2 / cpio / ubifs anywhere
```

Logs: `analysis/gpl_rootfs/logs/{zip_sha256,zip_listing,binwalk_scan_list,binwalk_all,binwalk_inner}.txt`.
The release is a **flat bag of upstream source snapshots** (busybox 1.30.1, musl 1.1.16,
u-boot 2018.03, lighttpd 1.4.65, lxc 2.1.1, …) packed from a build tree on
2023-07-27 (packer: `seven_tsai`, per tarball headers). Curiosity: some members are
**symlink stubs** — `cgi-io-19.tar.gz` is 141 bytes and contains only
`cgi-io -> ../../../feeds/packages/net/cgi-io`, i.e. **feed packages were not shipped**.

### 2.2 Firmware image availability (tier A attempt)

- Verizon ships CR200A updates OTA (3.2.0.15 → 3.2.0.21 → 3.4.0.4); no public download.
- Probed `verizon.com/content/dam/...` guesses → 302 redirects (no file).
- Probed `cpe-ems34.verizon.com/firmware/{cr200a_fw_*,lv65c_fw_*,WNC/*,…}` (the host that
  serves CR1000A/G3100 images) → connection refused from both GitHub Actions and this
  sandbox (the host answers only on Verizon's network). Log:
  `analysis/gpl_rootfs/logs/firmware_probe{,_cpe}.txt`.
- No firmware images on GitHub for this model (`gh` repo/code search).

### 2.3 Sibling firmware dump (tier B) — where binwalk really bites

`MeisterLone/Verizon-CR1000A` (60 MB) provides stock firmware artifacts. binwalk
(`scripts/binwalk_extract_rootfs.sh`, demo output `downloads/cr1000a-dump/helper_demo/`):

| File | binwalk signature | Result |
|---|---|---|
| `uImage-cr1000a.bin` (11.7 MB) | FIT image → gzip `Image-initramfs` (2022-05-12) → LZMA → **cpio** | initramfs rootfs **extracted** (656 entries) |
| `cr1000a_unencrypted_kernel.bin` (16.9 MB) | ARM64 kernel Image (4.4.60 strings) + gzip + LZMA + cpio | same initramfs |
| `cr1000a_openwrt_base.itb` (11.1 MB) | FIT → gzip → xz → ARM64 kernel (**5.15.104** strings) | community OpenWrt base image (OpenWrt-forum port) |
| `encrypted_kernel.img` (13.8 MB) | **no signatures** (encrypted) | opaque |
| `uboot.elf` (624 KB) | ELF ARM, **x509 certificates**, **AES S-boxes**, 20+ FIT DTB configs | U-Boot w/ secure boot + image decryption |

The cpio was carved by binwalk and unpacked with `scripts/extract_cpio.py` (pure-stdlib
newc extractor, written because the sandbox lacks `cpio`) into a 656-entry recovery/
initramfs rootfs. The **main rootfs is a LUKS-encrypted squashfs** (community research on
the hashcat forum documents decryption of full firmware images with keyfiles); the
encrypted rootfs image itself is not in the public dump.

## 3. Boot chain

```
Qualcomm PBL (ROM)
  └─ XBL/SBL (secure boot chain)
      └─ U-Boot 2018.03            ← GPL release ships u-boot-2018.03.tar.bz2 (tier A);
                                     uboot.elf (tier B) shows x509 secure-boot certs,
                                     AES image decryption, FIT configs
          └─ FIT/uImage kernel     ← ARM64 Linux (stock ≈ 4.4.60; initramfs embedded)
              └─ /init             ← "export PREINIT=1; exec /etc/preinit"  (tier B, verbatim)
                  └─ /etc/preinit  ← OpenWrt preinit dispatcher
                      └─ /lib/preinit/*  hooks, in order:
                          10_indicate_failsafe → 10_indicate_preinit → 10_sysinfo
                          → 30_failsafe_wait → 40_run_failsafe_hook → 50_indicate_regular_preinit
                          → 70_initramfs_test → 80_mount_root → 81_bd_check
                          → 81_urandom_seed (CR200A GPL, verbatim!) → 99_10_failsafe_login
                          → 99_10_run_init
                          └─ switch_root to main rootfs
                              (LUKS-mapped squashfs + LVM: S15lvm2, cryptsetup present)
                  └─ /sbin/init → procd
                      procd: - early -   (t≈21.5 s in boot log)
                      procd: - watchdog -
                      procd: - ubus -
                      procd: - init -
                      └─ rcS /etc/rc.d/S00… → S99   (107 services, §5)
```

Initramfs contents (tier B, `analysis/cr1000a_rootfs/`): busybox userland, `preinit`
framework in `lib/preinit/`, service accounts (`dnsmasq`, `lldp`, `network`…), factory/
recovery tools (`firstboot`, `jffs2reset`, `sysupgrade`, `upgraded`, `cryptsetup`,
`fw3`, `rpcd`, `logd`, `mdev`, `swconfig`, `rstpd`, `Qcmbr`/`ftm` QCA RF tools).
The `etc/banner` literally reads *"For those about to rock... (Chaos Calmer,
7382976+r49254)"* — the recovery environment is OpenWrt CC-based.

## 4. `/etc/init.d/` framework (what the scripts look like)

OpenWrt procd semantics (tier C baseline, `analysis/openwrt-18.06-baseline/etc/`):
scripts start with `#!/bin/sh /etc/rc.common`, declare `START=NN` (run order) and
optionally `USE_PROCD=1`; `rc.common` enables them via `/etc/rc.d/S$START$name`
symlinks which `procd` walks during `- init -`. Genuine CR200A-shipped examples
(tier A, `analysis/gpl_rootfs/unpacked/`):

**`qos-scripts/files/etc/init.d/qos`** (START=80, USE_PROCD=1):
```sh
#!/bin/sh /etc/rc.common
START=80
USE_PROCD=1
service_triggers() {
    procd_add_reload_trigger "qos"
    procd_add_validation validate_qos_section
    ...
start_service() {
    qos-start
    /usr/sbin/qos/qos_gmd_ucivol_gen.sh ...
```

**`ddns-scripts/files/ddns.init`** (START=99, USE_PROCD=1):
```sh
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "/usr/lib/ddns/dynamic_dns_updater.sh" "start"
    procd_set_param limits core="unlimited"
    procd_close_instance
}
```

**`urandom-seed/files/etc/init.d/urandom_seed`** (START=99, USE_PROCD=1) plus its
preinit hook `lib/preinit/81_urandom_seed` (seeds `/dev/urandom` from
`/etc/urandom.seed` before mount_root). All three map 1:1 onto `S99ddns`, `S80qos`,
`S99urandom_seed` in the real boot order (§5).

## 5. Services running on the device

The tier-B boot log (`analysis/cr1000a_rootfs/bootlog_service_order.txt`) records every
`procd: - rcS /etc/rc.d/Sxx… -` line — the complete enabled init.d set of the stock
VZSDK firmware, 107 units. Grouped:

| Group | Units (S-prefix = start order) |
|---|---|
| Early board bring-up | `S00arc_deviceup`, `S00arc_led`, `S00wifi_fw_mount`, `S01timer`, `S02sys_cpu_monitor`, `S10boot`, `S10boot-ucicu`, `S10system`, `S11sysctl`, `S11arc_glbcfg`, `S11arc_wlan_pre` |
| Platform/firmware (QCA) | `S08qrtr`, `S08boot-ftm`, `S09qca-iot` (runs `iotd`), `S11aqr113c_init` (Aquantia 2.5G PHY), `S15qca-acfg`, `S15qca-hostapd`, `S15qca-wpa-supplicant`, `S16qca-ssdk`, `S18rdpa_init`, `S19cnss_diag`, `S19qca-nss-ecm`, `S70qca-nss-drv`, `S72shortcut-fe`, `S16kevtmonitor`, `S16wan_mapi`, `S20rtl-9303` (RTL switch) |
| Core system | `S12log`, `S12rpcd`, `S12syslog-ng`, `S12arc_syslog_handle`, `S12arc_kernellog_handle`, `S13coredumper`, `S13debug`, `S15lvm2`, `S40fstab`, `S50cron`, `S60dbus`, `S90sysstat`, `S90backup`, `S98sysntpd`, `S98thermal`, `S98rngd`, `S99urandom_seed`, `S99system_info`, `S94gpio_switch`, `S96led`, `S98powerctl` |
| Network/firewall | `S20network`, `S20arc_firewall`, `S21arc_sysctl`, `S21conntrackd`, `S21dmcp`, `S30arc_route_table`, `S58dnsmasq`, `S60dhcpd`, `S80ipsec`, `S95arc_bridge_init`, `S18arc_passthrough` (IP passthrough), `S19arc_wan_mac`, `S13arc_wan_EEEmode`, `S98EEE_WAN`, `S85arc_mtu_speed_setup`, `S99ddns`, `S99mcproxy`, `S99miniupnpd` |
| Wi-Fi / mesh | `S86arc_wlan`, `S99arc_wlan_post`, `S87arc_wlsta_monitor_wd`, `S52wsplcd`, `S54hyfi-bridging`, `S55lbd`, `S56mesh_app`, `S99arc_ieee1905_owl` (IEEE 1905.1 / EasyMesh), `S97repacd`, `S99arc_igmp_snoop` |
| **Web / management** | **`S99zarc_lighttpd_luci`** (lighttpd + LuCI web GUI), `S12rpcd` (ubus JSON-RPC), `S90arc_appapi`, `S22arc_tr69` + `S23arc_tr69_monitor` (TR-069/CWMP remote mgmt), `S22arc_sshd`, `S75arc_mqtt`, `S80mosquitto`, `S99arc_cloud`, `S99arc_mcafee`, `S17devnotifid`, `S99arc-intf`, `S99arc_deviceready` |
| QoS/traffic | `S30arc_qos_init`, `S80qos`, `S70arc-trafstatd`, `S40skb_recycler`, `S18arc_passthrough` |
| Container / apps | `S99lxc-auto` (LXC — starts the **VZSDK container**), `S75install_mode`, `S75mcsd`, `S80autoconf`, `S90arc_appapi` |
| Factory/diagnostics | `S08boot-ftm`, `S97ftm`, `S98diag_socket_app`, `S98arc_lcmd`, `S10cosmos`, `S95done` |

CR200A cross-check (tier A): its GPL release contains exactly the building blocks these
units imply — `procd`, `ubus`, `uci`, `netifd`, `dnsmasq`, `firewall`-adjacent (iptables/
ipset/conntrack/ebtables/arptables/xtables-addons), `lighttpd`, `rpcd`(+`-mod-luci`,
`-mod-rrdns`), `cgi-io`, `uclient`, `lxc`, `mosquitto`, `openssh`, `syslog-ng`, `logrotate`,
`unbound`, `radvd`, `miniupnpd`, `avahi`, `lldpd`, `mcproxy`, `rstp`, `ddns-scripts`,
`qos-scripts`, `sscep`, `shadow`, `mtd-utils`, `fstools`, `fwtool`, `opkg`, `swconfig`.
WNC's own unit names (analogous to `arc_*`/`zarc_*`) are withheld with the rootfs.

## 6. Web server configuration

**The HTTP server is lighttpd 1.4.65** — shipped verbatim in the CR200A GPL release
(`gpl_release/lighttpd-1.4.65.tar.xz`), started by the `…lighttpd_luci` init unit on the
shared platform. There is **no uhttpd and no dropbear** in the CR200A package set
(OpenSSH 7.9p1 is present instead; busybox httpd source is also shipped but unused for
the GUI). The web GUI is **LuCI-derived** (boot log unit name `zarc_lighttpd_luci`;
`rpcd-mod-luci` + `cgi-io` + `uclient` in the GPL release).

Assembled picture of the management stack:

| Layer | Component (evidence) |
|---|---|
| TLS termination | lighttpd 1.4.65 with a self-signed cert — matches Verizon manuals' *"connection is not private → Proceed to 192.168.1.1 (unsafe)"* instructions |
| Listening endpoints | LAN `192.168.1.1` (WNC-CR200A/ARC-XCI55AX), hostname `mynetworksettings.com` (DNS rebind by dnsmasq) |
| Static UI + CGI | lighttpd `mod_cgi`/`mod_fastcgi` (source in release: `src/mod_cgi.c`, `mod_fastcgi.c`; reference configs `doc/config/conf.d/{cgi,fastcgi}.conf`), `cgi-io` helper for firmware/config upload (feed stub — source withheld) |
| RPC/API | `rpcd` (S12rpcd) exposing ubus over HTTP — the LuCI JSON-RPC backend; `rpcd-mod-luci`, `rpcd-mod-rrdns` plugins shipped |
| Aux transports | `libwebsockets` 3.1.0 (WebSocket push), `fcgi` 2.4.0, `luasocket` (Lua/LuCI), `lua` 5.1.5 |
| Auth | per-unit label password (see `docs/Verizon_Gateway_Default_Credentials.md`); `shadow` 4.8.1 in the package set |
| Sidecar services | `mosquitto` 1.6.9 (MQTT, `S80mosquitto`/`S75arc_mqtt`), `libstrophe` 0.9.2 (XMPP), `sscep` (SCEP cert enrollment), TR-069 agent (`S22arc_tr69`) for Verizon remote management |

What the device's actual `lighttpd.conf` contains is **not public** (it lives in the
withheld rootfs). The upstream reference config shipped in the GPL tarball
(`analysis/gpl_rootfs/unpacked/lighttpd-1.4.65/…/doc/config/lighttpd.conf`) shows the
standard module set; the device config adds the self-signed TLS cert and the
cgi/rpcd wiring above.

## 7. Caveats

1. **Tiering**: §5's unit names come from the CR1000A (Arcadyan-built). The CR200A
   (WNC-built) shares the Verizon VZSDK/OpenWrt platform and the §6 web stack (its own
   GPL release proves the components), but its exact `S*` names and vendor units are not
   public. Treat the table as *the service set of the shared firmware family*.
2. The stock main rootfs is **LUKS-encrypted**; nothing here extracts `/etc/config/*`
   or the real `lighttpd.conf` from a live CR200A/CR1000A rootfs image.
3. The initramfs banner ("Chaos Calmer") reflects the recovery environment's lineage;
   the running system is OpenWrt **18.06**-based per Verizon's disclosure.

## 8. Reproducing this analysis

```bash
# 1. Fetch + extract the CR200A GPL release (runs binwalk on the runner, commits evidence)
gh workflow run fetch-gpl-rootfs.yml --ref arena/86a82a72-os   # or: it auto-runs on push

# 2. Extract a root filesystem from any firmware image with binwalk
scripts/binwalk_extract_rootfs.sh <firmware.bin> out/         # scan, carve, unpack cpio,
                                                              # collect init.d + web configs
# (scripts/extract_cpio.py is used automatically when the cpio utility is absent)

# 3. The sibling dump analyzed here
git clone --depth 1 https://github.com/MeisterLone/Verizon-CR1000A downloads/cr1000a-dump
scripts/binwalk_extract_rootfs.sh downloads/cr1000a-dump/Firmware/uImage-cr1000a.bin out/
```

Companion documents: `docs/WNC-CR200A_FCC_Internal_Photos_Analysis.md` (hardware: IPQ8072A,
SDX65, QCN9074…), `docs/WNC-CR200A_Open_Source_Disclosure.md` (93-package inventory),
`docs/Verizon_Gateway_Default_Credentials.md` (admin/label credentials).
