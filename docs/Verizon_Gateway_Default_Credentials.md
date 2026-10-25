# Verizon Gateways — Publicly Known Default Credentials

A survey of **publicly documented** default login credentials for Verizon-branded
residential/business gateways, routers, and hotspots (Fios, 5G/LTE Home, DSL, Jetpack),
compiled 2026-10-25 from Verizon manuals/support pages, FCC-filed user guides, vendor
manuals, and aggregator lists.

> **Headline finding:** Verizon's modern gateways — including the **WNC-CR200A** — do
> **not** use a shared default like `admin`/`admin`. Each unit ships with a **unique
> admin password printed on its own label** (bottom of the Internet Gateway, rear/side
> of the Fios Router), and the web login asks for that password only (no username on the
> 5G/LTE gateways). Shared defaults like `admin`/`password` exist only on **legacy**
> hardware (2000s-era Actiontec/Westell DSL and early Fios units) and a few hotspots.

**Three different passwords, routinely confused:**

| Credential | Unlocks | Where it lives |
|---|---|---|
| **Admin / "Network Settings" password** | The router's web admin GUI | Label on the device (unique per unit) |
| **Wi-Fi password** (WPA2/WPA3 key) | Joining the wireless network | Same label (unique per unit; *not* the admin password) |
| **My Verizon account password** | verizon.com / the My Verizon app | Set at account registration |

A factory reset restores the **label** credentials (it does not introduce `admin`).

---

## 1. WNC-CR200A (Verizon Internet Gateway, 5G/LTE Home) — the reference case

| Item | Value | Source |
|---|---|---|
| Admin URL | `mynetworksettings.com` or `https://192.168.1.1` (self-signed cert → *Advanced → Proceed*) | [CR200A User Manual v2](https://www.verizon.com/support/pdf/user_guide/Verizon-Internet-Gateway-WNC-CR200A-User-Manual-v2.pdf), [KB 301456](https://www.verizon.com/support/knowledge-base-301456/) |
| Username | **None requested** — the login screen has only a password field | [KB 301456](https://www.verizon.com/support/knowledge-base-301456/), [Techdows](https://techdows.com/how-to-log-in-to-verizon-router.html) |
| Admin password | **Unique per device**, "the password that is printed next to the *Password* on the label on the bottom of the Gateway" | [CR200A User Manual v2](https://www.verizon.com/support/pdf/user_guide/Verizon-Internet-Gateway-WNC-CR200A-User-Manual-v2.pdf) |
| Wi-Fi name / password | Also on the bottom label, separate from the admin password | [KB 305611](https://www.verizon.com/support/knowledge-base-305611/), [KB 305616](https://www.verizon.com/support/knowledge-base-305616/) |
| After factory reset | Label values return | [Techdows](https://techdows.com/how-to-log-in-to-verizon-router.html) |
| First-time setup | Easy Setup Wizard on first login; if the unit was activated via the My Verizon app, the admin password may have been changed during activation (the printed one then stops working until a factory reset) | CR200A manual; [MacMyths](https://macmyths.com/how-to-log-in-to-verizon-router/) |

**Label anatomy (primary source: FCC Internal Photos exhibit photo (1) for FCC ID
NKR-LV65C-T3, `downloads/fcc/WNC-CR200A_FCC_Internal_Photos_6604463.pdf` p.1):** the
certification-sample unit's bottom label prints:

```
MODEL/SKU: WNC-CR200A
ICCID: 89148000008449920473            IMEI: 357473870016852
Wi-Fi Name:     Verizon_V9BC4X         (default SSID pattern: Verizon_XXXXXX)
Wi-Fi Password: cod-runway4-nit         ← unique, randomly generated per unit
support.verizon.com                     [QR code]
```

Verizon's own documentation ([KB 305616](https://www.verizon.com/support/knowledge-base-305616/))
states that production labels also carry **`Network Settings: URL and Password`** — the
admin credential. Either way, the CR200A's credentials are **per-unit random strings
printed on the device label**, not a shared default such as `admin`. Anyone with
physical access to the label has the Wi-Fi key and (on production units) the admin
password — the standard trade-off of label-based credentials.

---

## 2. 5G / LTE Home & Business gateways (current generation)

| Model | Service | Admin URL | Username | Default admin password | Sources |
|---|---|---|---|---|---|
| **WNC-CR200A** | 5G/LTE Home "Verizon Internet Gateway" | `mynetworksettings.com` / `https://192.168.1.1` | *(none)* | Unique, bottom label ("Password") | [KB 301456](https://www.verizon.com/support/knowledge-base-301456/), [CR200A manual](https://www.verizon.com/support/pdf/user_guide/Verizon-Internet-Gateway-WNC-CR200A-User-Manual-v2.pdf) |
| **ARC-XCI55AX** | 5G Home "Verizon Internet Gateway" | `mynetworksettings.com` / `https://192.168.1.1` | *(none)* | Unique, bottom label | [KB 301456](https://www.verizon.com/support/knowledge-base-301456/) |
| **ASK-NCQ1338 / ASK-NCQ1338FA** | 5G/LTE Home | `mynetworksettings.com` / `https://192.168.0.1` | *(none)* | Unique, bottom label ("Network Settings: URL and Password") — **but see exception below** | [KB 301456](https://www.verizon.com/support/knowledge-base-301456/), [NCQ-1338 user guide](https://scache.vzw.com/content/dam/support/pdf/user_guide/verizon-internet-gateway-ncq-1338-user-guide-v1.pdf) |
| **ASK-NCM1100** | LTE Home "Verizon Internet Gateway" | `mynetworksettings.com` / `https://192.168.1.1` | *(none)* | Unique, label on the back | [NCM1100 manual](https://www.verizon.com/content/dam/support/pdf/user_guide/Verizon-Internet-Gateway-(ASK-NCM1100)-User-Manual-v1.pdf) |
| **LVSKIHP** | 5G Internet Gateway (1st gen, "cube") | `http://my.router` / `192.168.0.1` | *(none — "Wi-Fi / WebGUI password")* | Unique, bottom label ("Administrative URL / Password"); "Forgot Admin Password?" flow uses a security question | [KB 234498](https://www.verizon.com/support/knowledge-base-234498/), [KB 227010](https://www.verizon.com/support/knowledge-base-227010/) |
| **ARC-KVD21** | 5G Home (cylinder) | (per label) | — | Unique, base/rear label (secondary source only) | [techflare.net](https://techflare.net/what-is-the-default-admin-password-for-a-verizon-router-full-guide/) |
| **Verizon 4G LTE Broadband Router** (Novatel) | LTE Business/Office | (per label) | — | "The default network password can be found on label at the back of the router" | [KB 65069](https://www.verizon.com/support/knowledge-base-65069/) |
| **FSNO21VA** (Business Internet Gateway) | Business | `setup.verizon.com/businessinternetgateway` | — | "Admin URL and Admin password" printed on the back label | [Verizon instructions manual](https://www.manualslib.com/manual/2862315/Verizon-Fsno21va.html) |
| **D-Link 2750B / GT784WNV** (Business static-IP kits) | DSL Business | `http://192.168.1.1` | `admin` | "Personal Password located on sticker on bottom of the modem" | [Verizon static-IP guide](https://www.verizon.com/about/sites/default/files/Static-IP-Set-Up-D-Link-Actiontec-Guide-for-Business.pdf) |

### ⚠ Documented exception — ASK-NCQ1338 `admin` / `admin`

An **FCC-filed user guide** for the ASK-NCQ1338 (exhibit
[H8N-ASK-NCQ1338/5202085](https://fcc.report/FCC-ID/H8N-ASK-NCQ1338/5202085.pdf))
explicitly instructs: *"Log in to the Web UI using the default username: **admin** and
password: **admin**"*, then change the Wi-Fi password and the Web UI password under
**Device Settings > Admin Password**. Later Verizon guides for the same model describe
the label password instead. Treat `admin`/`admin` as a **known default for at least some
ASK-NCQ1338 firmware/documentation revisions** — the only current-generation gateway for
which a shared default is officially documented.

---

## 3. Fios routers

| Model | Admin URL | Username | Default admin password | Sources |
|---|---|---|---|---|
| **Verizon Router CR1000A / CR1000B** | `myfiosgateway.com` / `mynetworksettings.com` / `192.168.1.1` | `admin` (if prompted) | Unique **"Network Settings Password"** on rear label | [Verizon Router FAQs](https://www.verizon.com/content/dam/verizon/support/consumer/documents/internet/verizon-router_faqs.pdf), [KB 239713](https://www.verizon.com/support/knowledge-base-239713/), [KB 308501](https://www.verizon.com/support/knowledge-base-308501/) |
| **Fios Router G3100** | `myfiosgateway.com` / `192.168.1.1` | `admin` | Unique **"Admin Password"** on bottom label | [Fios Router FAQs](https://www.verizon.com/support/residential/internet/equipment/routers/fios-router/) |
| **FiOS Quantum Gateway G1100** | `myfiosgateway.com` / `192.168.1.1` | `admin` | Unique **"Administrator password"** on side label; the 2014 user guide notes label password letters are **all lower-case** | [G1100 user guide](https://www.verizon.com/about/sites/default/files/fios-qgr-userguide140925.pdf), [Quantum Gateway support](https://www.verizon.com/support/residential/internet/equipment/routers/fios-quantum-gateway) |
| **Actiontec MI424WR** (Fios rev. A–I) | `192.168.1.1` | `admin` | **Era-dependent:** early units `password`; Verizon later switched to the **unit's serial number**; the 2011 rev. I manual instructs the "Default Password" printed on the bottom label | [SuperUser (quoting Verizon)](https://superuser.com/questions/547137/need-default-password-for-mi424wr-router), [rev. I manual](https://www.verizon.com/content/dam/verizon/support/consumer/documents/vz_bhr3_rev_i_user_manual.pdf), [Verizon community](https://forums.verizon.com/t5/Fios-Internet-and-High-Speed/Login-to-Actiontec-MI424WR-Router/m-p/1376839), [router-reset](https://www.router-reset.com/default-password-ip-list/Actiontec) |
| **CHR30A** (Fios mesh extender) | `mynetworksettings.com` | — | Managed by the CR1000A parent | [Technobezz](https://www.technobezz.com/how-to-change-your-verizon-routers-wi-fi-and-admin-passwords) |

**About the widespread `admin`/`admin` claims for the G1100:** aggregator sites
([portforward](https://portforward.com/verizon/passwords/),
[modemly](https://modemly.com/Verizon-FiOS-G1100-router-setup),
[Bitdefender support](https://www.bitdefender.com/consumer/support/answer/3630/)) list
`admin`/`admin`, but Verizon's official guide prints per-unit Administrator passwords
on the label, Tenable's 2019 research states *"Each customer is given a different
Wireless network name, Wireless password, and Administrator password"*
([Tenable TRA-2019-17](https://www.tenable.com/security/research/tra-2019-17)), and user
reports describe randomized passwords on G1100s
([r/Fios](https://www.reddit.com/r/Fios/comments/fqjzgv/no_admin_username_or_password_info_on_this_g1100/)).
Conclusion: `admin`/`admin` is **list-site folklore** for the G1100 — useful only as a
first try against an old or user-modified unit.

---

## 4. Legacy DSL & early Fios (the genuinely shared defaults)

These 2000s-era units are where real, universal default credentials live:

| Model | URL | Username | Password | Sources |
|---|---|---|---|---|
| Actiontec **GT704WG** (Verizon DSL) | `192.168.1.1` | `admin` | `password` (official manual, all lower-case) | [Verizon GT704WG manual](https://www.verizon.com/content/dam/verizon/support/consumer/documents/actiontecgt704wguser.pdf) |
| Actiontec **GT784WNV** (Verizon DSL) | `192.168.1.1` | `admin` | `password` per the manual; Verizon states the password "may have been changed to your router's **serial number**", and ISP-branded units carry a printed user/pass sticker | [Verizon GT784WNV support](https://www.verizon.com/support/residential/internet/equipment/routers/actiontec-gt784wnv), [manual](https://manuals.plus/verizon/verizon-actiontec-gt784wnv-wireless-gateway-user-manual), [Verizon community](https://forums.verizon.com/t5/High-Speed-Internet/GT784WNV-default-password/td-p/806626) |
| Westell **6100** (Verizon DSL) | `192.168.1.1` | `admin` | `password` (some lists: `admin`; some early configs: the customer's **verizon.net** ID/password) | [portforward](https://portforward.com/westell/passwords/), [modemly](https://modemly.com/Westell-6100-router-setup), [dslreports](https://www.dslreports.com/forum/r14572508-Westell-6100-default-login) |
| Westell **VersaLink 327W** | `192.168.1.1` | `admin` | `password` (Verizon firmware); `admin` (Westell firmware) | [guías/credential list](https://guiasvarias.com/contrasena-router-password-router/) |
| Westell **VersaLink 7500** (A90-750015-07) | `192.168.200.1` (or `192.168.1.1`) | `admin` | `password` after factory reset (device then forces a password change) | [WikiDevi](https://wikidevi.wi-cat.ru/Westell_VersaLink_7500_(A90-750015-07)), [Verizon community](https://forums.verizon.com/t5/high-speed-internet/westell-versalink-7500-login-problem/td-p/348989) |
| Westell general | — | `admin` | `password`, `sysAdmin`, or `Administrator` variants; some units = verizon.net credentials | [Tech-FAQ](https://www.tech-faq.com/westell-default-password.html) |
| MI424WR rev C (refurb/mixed) | `192.168.1.1` | `admin` | unit's **serial number** | [router-reset](https://www.router-reset.com/default-password-ip-list/Actiontec) |

---

## 5. Jetpacks / mobile hotspots

| Model | Admin URL | Username | Default admin password | Sources |
|---|---|---|---|---|
| **MiFi 6620L** (Novatel/Inseego) | `my.jetpack` / `192.168.1.1` | *(none)* | **`admin`** (2014 user guide); viewable on the LCD (*Help > Jetpack Admin website*) | [6620L user guide](https://www.rentacomputer.com/new/tech/mi-fi/verizon-mifi-6620l.pdf), [manualslib](https://www.manualslib.com/manual/1327867/Verizon-Jetpack-Mifi-6620l.html) |
| **MiFi 7730L** (Novatel) | `my.jetpack` / `192.168.1.1` | *(none)* | **`admin`** ("The default Admin password is admin", user guide p.38); also shown on the display (*Help > Jetpack Admin website*) | [7730L user guide](https://ss7.vzw.com/is/content/VerizonWireless/Devices/Mifi/userguide/verizon-jetpack-mifi-7730l-ug.pdf) |
| **MiFi 8800L** (Inseego) | `my.jetpack` / `192.168.1.1` | *(none)* | **= the Wi-Fi password by default** (per-device random string shown on the device/label) | [KB 220811](https://www.verizon.com/support/knowledge-base-220811/), [8800L manual](https://ss7.vzw.com/is/content/VerizonWireless/Devices/Verizon/Jetpack%20MiFi%208800L/User%20Manual/verizon-jetpack-mifi-8800l-um.pdf) |
| **Jetpack AC791L** (Netgear) | `my.jetpack` / `192.168.1.1` | *(none)* | Per-device; hard reset restores "the default settings printed on the external label" | [KB 173715](https://www.verizon.com/support/knowledge-base-173715/) |
| **Orbic Speed RC400L** | `my.jetpack` / `192.168.1.1` | `admin` | **= the Wi-Fi password** (per-device) | [Orbic user guide](https://ss7.vzw.com/is/content/VerizonWireless/Catalog%20Assets/Devices/orbic/orbic-speed/ug/orbic-speed-mobile-hotspot-userguide-en_07072020.pdf) |

---

## 6. Naming variance for the same label credential

Depending on model/vintage, Verizon labels call the admin password:

- **"Password"** (WNC-CR200A manual wording), **"Admin Password"** (G3100, NCQ1338),
  **"Administrator password"** (G1100), **"Network Settings Password"** (CR1000A/B),
  **"Administrative URL / Password"** (LVSKIHP), **"Admin URL and Admin password"**
  (FSNO21VA), **"Default Password"** (MI424WR rev. I), **"Personal Password"**
  (business static-IP kits), and (per third-party guides) **"Device Access Code"**.

It is always the per-unit admin credential — never the Wi-Fi key, never the My Verizon
account password.

## 7. Security-relevant public research

- **FiOS Quantum Gateway G1100** (firmware 02.01.00.05): CVE-2019-3914 (authenticated
  command injection, CVSS 8.5), CVE-2019-3915 (login replay over non-enforced HTTP),
  CVE-2019-3916 (unauthenticated password-salt disclosure) — Tenable research, fixed in
  02.02.00.13. [Tenable TRA-2019-17](https://www.tenable.com/security/research/tra-2019-17),
  [The Hacker News](https://thehackernews.com/2019/04/verizon-wifi-router-security.html).
- **Actiontec MI424WR-GEN3I**: CVE-2013-0126 — CSRF in `index.cgi` (firmware 40.19.36)
  allowing admin-account addition / remote-administration enablement.
  [NVD](https://nvd.nist.gov/vuln/detail/CVE-2013-0126).
- **Actiontec GT784WN**: CVE-2015-2904 — **hardcoded credentials** in firmware before
  NCS01-1.0.13 give root via the web admin interface (i.e., a real "known default
  credential" beyond the label). [OpenCVE](https://app.opencve.io/cve/?vendor=actiontec).

**Practical guidance.** (1) On label-credential models there is nothing to "guess" —
the secrets are random per unit, so remote default-credential attacks don't work; but
(2) physical or photographic access to the label yields the Wi-Fi key and usually the
admin password — change both if that matters to you. (3) A factory reset returns the
label credentials, wiping custom ones. (4) On legacy Actiontec/Westell units, assume
`admin`/`password` (or the serial number) works until proven otherwise.

## 8. Sources & method

Primary sources are Verizon support pages and user manuals (verizon.com, scache.vzw.com,
ss7.vzw.com) and FCC-filed user guides; secondary sources (aggregator lists, community
threads, vendor pages) are labeled as such where they conflict. Where a shared default
and a label password are both documented for one model (MI424WR, GT784WNV, ASK-NCQ1338),
both are recorded with their era/revision. This document covers publicly published
information only — it is a reference for device owners and researchers, not a guide to
accessing devices you don't own.

Companion docs in this repo: `docs/WNC-CR200A_FCC_Internal_Photos_Analysis.md` (hardware
identification from the same FCC exhibit), `docs/WNC-CR200A_Open_Source_Disclosure.md`
(firmware/OSS release).
