# Verizon Internet Gateway (WNC-CR200A) Open Source Software Disclosure & Package Reference

## 1. Official Verizon Open Source Portal Downloads

The official open-source software package and disclosure documents for the **Verizon Internet Gateway (WNC-CR200A)** are published on Verizon's Free and Open Source Software Portal:

- **Portal Page:** <https://www.verizon.com/support/residential/internet/equipment/open-source-software>
- **Official GPL Source Code Package (`.zip`):**
  - **Release:** `Verizon Internet Gateway (WNC-CR200A) GPL release 3.2.0.13`
  - **Direct Download URL:** <https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/WNC-CR200A_gpl_release_3.2.0.13.zip>
- **Official Open Source Disclosure Document (`.pdf`):**
  - **Document:** `WNC-CR200A_Open_Source_Resource_3.2.0.13.pdf` (Dated `2023-08-21`)
  - **Direct Download URL:** <https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/WNC-CR200A_Open_Source_Resource_3.2.0.13.pdf>
- **VZSDK Container Open Source Disclosure (`.pdf`):**
  - **Document:** `Verizon-Fios-Router-(G3100-CR1000A-CR1000B)-additional-open-source-disclosures-for-VZSDK-Container.pdf`
  - **Direct Download URL:** <https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/Verizon-Fios-Router-(G3100-CR1000A-CR1000B)-additional-open-source-disclosures-for-VZSDK-Container.pdf>

---

## 2. Device Hardware & Firmware Architecture Summary

| Attribute | Details |
| :--- | :--- |
| **Product Name** | Verizon Internet Gateway |
| **Model / SKU** | `WNC-CR200A` |
| **Manufacturer** | Wistron NeWeb Corporation (WNC) |
| **FCC ID** | `NKR-LV65C-T3` |
| **SoC / Wireless Platform** | Qualcomm Dragonwing NPro 6E Platform (Tri-band Wi-Fi 6E: 2.4 GHz, 5 GHz, 6 GHz) |
| **Cellular Modem** | Qualcomm Snapdragon X65 5G Modem-RF System (3GPP Release 16) |
| **Ethernet Ports** | 2x RJ-45 LAN ports |
| **Base Operating System** | OpenWrt 18.06 Linux (`musl` 1.1.16, `busybox` 1.30.1, `procd`/`netifd`/`ubus`/`fstools`) |
| **Web UI / API Stack** | `lighttpd` 1.4.65 + `fcgi` 2.4.0 + `cgi-io` 19 + `lua` 5.1.5 / `jansson` 2.7 / `json-c` 0.13.1 |
| **Container Runtime** | `lxc` 2.1.1 (`VZSDK` container environment) |
| **GPL Release Version** | `3.2.0.13` (Subsequent field OTA releases include `3.2.0.15`, `3.2.0.21`, and `3.4.0.4`) |

---

## 3. Disclosed Firmware Open-Source Components (Release `3.2.0.13`)

Below is the structured component table extracted from `WNC-CR200A_Open_Source_Resource_3.2.0.13.pdf`:

| Package Name | Version | License | Upstream Download Site |
| :--- | :--- | :--- | :--- |
| `adb` | `1.0.32` | Apache-2.0 | `https://android.googlesource.com/platform/system/core` |
| `arptable` | `2015-05-20` | GPL-2.0 | `https://git.netfilter.org/arptables` |
| `attr` | `2.4.48` | LGPL-2.1 / GPL-2.0 | `http://git.savannah.nongnu.org/cgit/attr.git/snapshot` |
| `avahi` | `0.8` | LGPL-2.1 | `http://avahi.org/` |
| `busybox` | `1.30.1` | GPL-2.0 | `http://busybox.net/` |
| `bzip2` | `1.0.8` | BZIP2 | `http://www.bzip.org/` |
| `ca-certificates` | `20190110` | GPL-2+ | `http://ftp.debian.org/debian/pool/main/c/ca-certificates` |
| `c-ares` | `1.15.0` | MIT | `http://c-ares.haxx.se/` |
| `cgi-io` | `19` | GPL-2.0 | `https://git.openwrt.org/feed/packages` |
| `conntrack-tools` | `2018-05-01` | GPL-2.0 | `http://conntrack-tools.netfilter.org/` |
| `cryptsetup` | `1.7.5` | GPL-2.0+ / LGPL-2.1+ | `http://ftp.iij.ad.jp/pub/linux/kernel/linux/utils/cryptsetup/v1.7/` |
| `curl` | `7.64.1` | MIT | `http://curl.haxx.se/` |
| `dbus` | `1.12.12` | AFL-2.1 | `https://dbus.freedesktop.org/releases/dbus/` |
| `ddns-scripts` | `2.7.8` | GPL-2.0 | `https://openwrt.org/packages/pkgdata/ddns-scripts` |
| `dhcp` | `4.4.1` | MPL-2.0 | `https://www.isc.org/downloads/` |
| `dnsmasq` | `2.8` | GPL-2.0 | `http://www.thekelleys.org.uk/dnsmasq/` |
| `e2fsprogs` | `1.44.5` | GPL-2.0 | `http://e2fsprogs.sourceforge.net/` |
| `ebtables` | `2018-06-27` | GPL-2.0 | `https://git.netfilter.org/ebtables` |
| `ethtool` | `3.18` | GPL-2.0 | `http://www.kernel.org/pub/software/network/ethtool/` |
| `expat` | `2.2.9` | MIT | `https://libexpat.github.io/` |
| `fcgi` | `2.4.0` | Open Market Licence | `http://www.fastcgi.com/dist/` |
| `fstools` | `2020-05-12` | GPL-2.0 | `https://git.openwrt.org/project/fstools.git` |
| `fuse-utils` | `2.9.7` | LGPLv2.1 / GPLv2 | `http://fuse.sourceforge.net/` |
| `fwtool` | `2` | GPL-2.0 | `https://github.com/openwrt/openwrt/tree/openwrt-18.06/package/system/fwtool` |
| `gettext (libintl)` | `0.19.8.1` | LGPL-2.1 | `http://www.gnu.org/software/gettext/` |
| `glib` | `2.58.3` | LGPL-2.1 | `https://ftp.gnome.org/pub/gnome/sources/glib/2.58/` |
| `gmp` | `6.1.2` | GPL-2.0+ | `http://gmplib.org/` |
| `i2c-tools` | `3.1.2` | GPLv2 | `http://dl.lm-sensors.org/i2c-tools/releases/` |
| `iperf` | `2.0.13` | BSD-3-Clause | `https://github.com/esnet/iperf` |
| `iperf3` | `3.7` | BSD-3-Clause | `https://downloads.es.net/pub/iperf` |
| `iproute2` | `4.0.0` | GPL-2.0 | `http://www.linuxfoundation.org/collaborate/workgroups/networking/iproute2` |
| `ipset` | `7.3` | GPL-2.0 | `http://ipset.netfilter.org/` |
| `iptables` | `1.8.3` | GPL-2.0 | `https://netfilter.org/projects/iptables/files/` |
| `iw` | `5.0.1` | GPL-2.0 | `http://ftp.iij.ad.jp/pub/linux/kernel/software/network/iw/` |
| `jansson` | `2.7` | MIT | `http://www.digip.org/jansson/releases/` |
| `json-c` | `0.13.1` | MIT | `https://s3.amazonaws.com/json-c_releases/releases/` |
| `jsonfilter` | `2018-02-04` | ISC | `http://git.openwrt.org/?p=project/jsonpath.git` |
| `libaio` | `0.3.112` | LGPL-2.1-only | `https://releases.pagure.org/libaio` |
| `libarchive` | `3.4.2` | BSD-2-Clause | `https://www.libarchive.org/` |
| `libassuan` | `2.5.3` | GPL-2.0 | `ftp://ftp.gnupg.org/gcrypt/libassuan/` |
| `libcap` | `2.27` | GPL-2.0 | `https://mirrors.edge.kernel.org/pub/linux/libs/security/linux-privs/libcap2/` |
| `libdaemon` | `0.14` | LGPL-2.1 | `http://0pointer.de/lennart/projects/libdaemon/` |
| `libedit` | `20191025-3.1` | BSD-3-Clause | `http://thrysoee.dk/editline/` |
| `libevent` | `2.1.11` | BSD-3-Clause | `http://www.monkey.org/~provos/libevent/` |
| `libffi` | `3.2.1` | MIT | `https://sourceforge.org/pub/libffi/` |
| `libgcrypt` | `1.7.10` | LGPL-2.1+ / GPL-2.0+ | `ftp://ftp.gnupg.org/gcrypt/libgcrypt` |
| `libgpg-error` | `1.27` | LGPL-2.1+ | `ftp://ftp.gnupg.org/gcrypt/libgpg-error` |
| `libiconv` | `1.11.1` | LGPL-2.0 | `http://www.gnu.org/software/libiconv/` |
| `libiwinfo` | `2019-10-16` | GPL-2.0 | `https://git.openwrt.org/project/iwinfo.git` |
| `libksba` | `1.3.5` | GPL-2.0 | `https://www.gnupg.org/ftp/gcrypt/libksba/` |
| `libmnl` | `1.0.4` | LGPL-2.1+ | `http://www.netfilter.org/projects/libmnl/` |
| `libnetfilter-conntrack` | `2018-05-01` | GPL-2.0+ | `http://www.netfilter.org/projects/libnetfilter_conntrack/` |
| `libnetfilter-cthelper` | `1.0.0` | GPL-2.0+ | `http://www.netfilter.org/projects/libnetfilter_cthelper/` |
| `libnetfilter-cttimeout` | `1.0.0` | GPL-2.0+ | `http://www.netfilter.org/projects/libnetfilter_cttimeout/` |
| `libnetfilter-queue` | `2017-06-27` | GPL-2.0+ | `http://www.netfilter.org/projects/libnetfilter_queue/` |
| `libnfnetlink` | `1.0.1` | GPL-2.0+ | `http://netfilter.org/projects/libnfnetlink/` |
| `libnl` | `3.4.0` | LGPL-2.1 | `http://www.infradead.org/~tgr/libnl/files/` |
| `libnl-tiny` | `0.1` | LGPL-2.1 | `https://openwrt.org/docs/techref/libnl` |
| `libpcap` | `1.9.1` | BSD-3-Clause | `http://www.tcpdump.org/` |
| `libroxml` | `2.3.0` | LGPL-2.1 | `http://download.libroxml.net/pool/v2.x` |
| `librpc` | `2015-11-04` | LGPL-2.1 | `https://git.openwrt.org/project/librpc-uclibc.git` |
| `libstrophe` | `0.9.2` | MIT | `http://strophe.im/libstrophe` |
| `libubox` | `2020-05-25` | ISC | `https://git.openwrt.org/?p=project/libubox.git` |
| `libusb` | `1.0.22` | LGPL-2.1 | `http://libusb.info/` |
| `libwebsockets` | `3.1.0` | LGPL-2.1+exception | `https://github.com/warmcat/libwebsockets` |
| `libxml2` | `2.9.9` | MIT | `http://gd.tuwien.ac.at/languages/libxml/` |
| `lighttpd` | `1.4.65` | BSD-3-Clause | `http://www.lighttpd.net/` |
| `lldpd` | `0.7.15` | ISC | `http://media.luffy.cx/files/lldpd` |
| `logrotate` | `3.15.0` | GPL-2.0-or-later | `https://github.com/logrotate/logrotate` |
| `lua` | `5.1.5` | MIT | `http://www.lua.org/` |
| `luasocket` | `3.0-rc1-20130909` | MIT | `https://github.com/diegonehab/luasocket.git` |
| `lvm2` | `2.03.02` | GPL-2.0 / LGPL-2.1 | `http://ftp.gwdg.de/pub/linux/sources.redhat.com/lvm2/` |
| `lxc` | `2.1.1` | LGPL-2.1+ / BSD-2-Clause / GPL-2.0 | `https://linuxcontainers.org/lxc/downloads/` |
| `lzo` | `2.10` | GPL-2.0+ | `http://www.oberhumer.com/opensource/lzo/` |
| `mbedtls` | `2.16.6` | GPL-2.0+ | `https://tls.mbed.org` |
| `mcproxy` | `2017-08-24` | GPL-2.0+ | `git://github.com/mcproxy/mcproxy.git` |
| `miniupnpd` | `2.1` | BSD-3-Clause | `http://miniupnp.free.fr/files` |
| `mosquitto` | `1.6.9` | BSD-3-Clause | `https://mosquitto.org/files/source/` |
| `mtd` | `21` | GPL-2.0+ | `http://openwrt.org/` |
| `mtd-utils` | `2.1.1` | GPL-2.0 | `http://www.linux-mtd.infradead.org/` |
| `musl` | `1.1.16` | MIT | `http://www.musl-libc.org` |
| `ncurses` | `6.1` | MIT | `http://www.gnu.org/software/ncurses/` |
| `ndisc6` | `1.0.4` | GPL-2.0 | `https://www.remlab.net/files/ndisc6` |
| `netifd` | `2019-08-05` | GPL-2.0 | `https://git.openwrt.org/?p=project/netifd.git` |
| `netpgpverify` | `20150204` | BSD | `http://www.netpgp.com/src/` |
| `nettle` | `3.5.1` | GPL-2.0+ | `http://www.lysator.liu.se/~nisse/nettle/` |
| `npth` | `1.6` | GPL-2.0 | `https://www.gnupg.org/ftp/gcrypt/npth/` |
| `openssh` | `7.9p1` | BSD, ISC | `https://www.openssh.com/` |
| `openssl` | `1.1.1g` | OpenSSL | `http://www.openssl.org/` |
| `openwrt-keyring` | `2019-07-25` | GPL-2.0 | `https://git.openwrt.org/keyring.git` |
| `opkg` | `0.4.2` | GPL-2.0 | `https://git.openwrt.org/project/opkg-lede.git` |
| `pcre` | `8.43` | BSD-3-Clause | `https://www.pcre.org/` |
| `pcre2` | `10.32` | BSD-3-Clause | `https://www.pcre.org/` |
