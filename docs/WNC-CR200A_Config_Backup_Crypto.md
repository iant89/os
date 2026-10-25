# WNC-CR200A / VZSDK — Configuration Backup Cryptography

How the Verizon gateway "Save & Restore" configuration backup (`.cfg`) is
encrypted, how to **decrypt** it, and what the plaintext contains. Method
recovered from community reverse engineering of the CR1000A firmware and
**empirically verified here** against a real CR1000A backup (fw 3.1.0.21).
Research scope: decryption and plaintext analysis only — this document and
`scripts/config_crypto/cfg_backup_tool.py` deliberately stop at inspection;
repacking/re-encryption tooling is out of scope (see §6). Compiled 2026-10-25.
Companions: `docs/WNC-CR200A_Web_Admin_Auth.md` (rpcd/uci auth),
`docs/WNC-CR200A_Boot_Process_and_Services.md` (`80_mount_root`, LUKS).

## 0. TL;DR

- `.cfg` backups are **AES-256-CBC** ciphertext with a per-file 16-byte **IV
  appended at the end of the file**; the plaintext is a **tar archive** of the
  uci config tree + SQLite state DBs.
- The AES key is **wrapped** (AES-256-CBC) under a **constant, firmware-embedded
  key** (`egjyodltjhpdkgtkh234p6567la20flv` / IV `6a70646c69667764`) — i.e. the
  scheme provides obfuscation, not confidentiality: anyone with a backup file
  and the public constants can decrypt it.
- Integrity is **fake**: the tar member `backup_md5` is supposed to hold an MD5
  of the backup, but the firmware writes/accepts the **empty-file MD5 stub**
  (`d41d8cd98f00b204e9800998ecf8427e`) and never verifies it. There is no MAC.
- **Verified**: `scripts/config_crypto/cfg_backup_tool.py` decrypted
  `Configs/CR1000A_V3.1.0.21_backup.cfg` from the public MeisterLone dump →
  35-member gzip tar (uci configs + 3 SQLite DBs). Results in §3.
- On the **CR200A** the format is expected to be identical (same VZSDK `arc_*`
  / `libmapi_backup` lineage) — verify-live steps in §5.

## 1. File format (specification)

```
.cfg container:
    +-----------------------------------------------+----------------+
    |  AES-256-CBC ciphertext (PKCS#7 padded tar)   |  IV (16 B)     |
    +-----------------------------------------------+----------------+
    |<------------- size = n*16 ------------------->|<-- last 16 B ->|

    plaintext_tar = AES-256-CBC-decrypt(K_cfg, IV_file, ciphertext)
    K_cfg         = AES-256-CBC-decrypt(K_wrap, IV_hard, wrapped_key)[:32]

Constants (from firmware buffers; "obfuscated" as hex+zero-pad):
    K_wrap       = "egjyodltjhpdkgtkh234p6567la20flv"   (32 ASCII bytes)
    IV_hard      = "6a70646c69667764"                   (16 ASCII bytes)
    wrapped_key  = 2e0ce09b5d412c36430bed8fb61af11b
                   8834877351293fceedb55e812b9e8daa
                   81e0c617117de5b87c93b505200c9b20     (48 B)
    IV_file      = random per backup, stored as the last 16 bytes
```

- Plaintext is a **tar** (community repack used `tar.gz`; the device's
  `libmapi_backup.so` decompresses both — the real sample backup is gzip tar,
  consistent with `tar czf`-style creation on-device).
- Equivalent device-side restore code (community grep of the rootfs):
  `openssl enc -d -aes-256-cbc … -pass pass:$encrypt_key` where
  `encrypt_key=get_encrypt_key` unwraps `K_cfg` as above (OpenWrt forum, p.8).
- Historical lineage: FIOS-**G1100** (`/sbin/frontier4` /
  `getEncryptedBase64Backup()` in bhr4) used `EVP_aes_256_cbc` + Base64 with a
  runtime-generated-but-fixed key (gorgias.me, 2017); the G1100 community tools
  `gwdecrypt.py`/`gwencrypt.py` (The5heepDev/FIOS-G1100) predate the CR1000A
  work. The CR1000A scheme adds the wrapped-key indirection and raw (non-b64)
  framing.

## 2. Integrity model (or lack of one)

The tar contains `backup_md5` — by design an MD5 over the backup. In practice
the firmware **generates the stub itself** and never checks it: the real
vendor-created sample backup contains exactly

```
d41d8cd98f00b204e9800998ecf8427e  -        # = MD5("")
```

which the community packer reproduces ("firmware has a bug where it doesn't
actually generate or check real md5"). Consequences:

- **No authentication of backups**: a modified/repacked backup is accepted
  (community: OEM `libmapi_backup.so` "verifies and decompresses repacked
  configs with no problems" — i.e. the verify step is satisfiable with the
  stub).
- Device binding ("only configuration files saved on a specific Verizon Router
  can be applied to that Verizon Router", CR1000A user guide p.96) is enforced
  in restore **logic** (e.g. `uci/hal` carries `model_name 'CR1000A'`; likely
  further serial/MAC checks in `.db`), not cryptographically.

This is a finding in its own right (V-10 in the web audit's terms): config
restore is an **unauthenticated** input path. Defensive implications in §7.

## 3. Empirical results (this repo)

Input: `downloads/cr1000a-dump/Configs/CR1000A_V3.1.0.21_backup.cfg`
(public analysis dump, 11,680 B — owner-published for research).

| Step | Result |
|---|---|
| container check | 11,680 B, 16-aligned; trailing IV `4c8faf36e32fa325ecd4c4cba4609936` |
| key unwrap | OK — unwrapped key present (fingerprint sha256/8 `a5f1a17c`) |
| payload decrypt | OK — 11,656 B, **gzip tar** |
| members | 35 (inventory below) |
| `backup_md5` | `d41d8cd98f00b204e9800998ecf8427e  -` (stub — §2) |

Plaintext inventory (structure only; values/secrets withheld):

| Member | Size | Content |
|---|---|---|
| `uci/` (30 files) | ~15 KB | uci config tree: `rpcd` (web logins: login/username/password/resetdefault), `httpd` (ports/https), `system` (names, timeserver, gui_mode), `network`, `wan`, `lan`, `dhcp`, `dhcpv6`, `dnsmasq`, `firewall_generic`, `firewall_log`, `ddns`, `dmz`, `upnpd`, `qos`, `static_route`, `moca`, `mtu`, `led`, `hosts`, `dns`, `ethernet`, `luci`, `mcafee`, `arc_vlanif`, `arc_syslog_ng`, `arc_wireless` (3× `wifi-device`, 7× `wifi-infterface` [vendor's typo], `proj-vz`, `wifi-extension`), `hal` (`model_name 'CR1000A'`), `backup` |
| `.db` | 135,168 B | **SQLite 3** (main device state DB) |
| `.cosmos_db` | 12,288 B | **SQLite 3** (`S10cosmos` service DB — cf. boot analysis) |
| `.oie_db` | 86,016 B | **SQLite 3** |
| `backup_md5` | 36 B | MD5 stub (§2) |

So a decrypted backup yields **essentially the entire device configuration**,
including credential material (Wi-Fi PSKs in `arc_wireless`, web-login hashes
in `rpcd`, DDNS credentials, etc.) — it must be handled as a secret store.

Note on "default config": factory defaults are uci defaults inside the
LUKS-sealed rootfs (`/etc/config/*`), not shipped as a `.cfg`; a
factory-defaulted device's first backup ≈ those defaults + device identity.
The sample above is a configured-device backup, which is the more interesting
analysis target anyway.

## 4. Relation to rootfs LUKS (different keys!)

Do not conflate the two crypto systems (both discussed in
`docs/WNC-CR200A_Boot_Process_and_Services.md` §LUKS and the hidden-endpoints
doc §4):

| | Rootfs (boot) | Config backup (Save & Restore) |
|---|---|---|
| Algorithm | LUKS (AES-XTS-plain64, 256-bit MK) | AES-256-CBC + wrapped key |
| Key material | `/etc/keyfile` in initramfs | constant `K_wrap`/`wrapped_key` in firmware |
| Where | eMMC `rootfs`/`rootfs_1` partitions | web UI backup file |

Both keys are recoverable from public artifacts — the platform's storage crypto
is obfuscation, not protection.

## 5. CR200A applicability — verify-live checklist

The CR200A shares the VZSDK platform (`arc_*` services, `S10cosmos`,
`/etc/config/hal`, identical Save & Restore UI flow), so the same format is
expected. The CR200A GPL release does **not** include the proprietary
`libmapi_backup`/`get_encrypt_key` components (not in
`manifest/wnc-cr200a-open-source-packages.json`), so confirm on the lab VM:

1. Take a backup: **Advanced → Utilities → Save & Restore → Save as file**.
2. `python3 scripts/config_crypto/cfg_backup_tool.py info <backup.cfg>` —
   expect 16-aligned size + trailing IV, no `Salted__` header.
3. `… inspect <backup.cfg>` — expect uci/ + SQLite DBs + `backup_md5` stub.
4. If unwrap fails, dump `get_encrypt_key` / `libmapi_backup.so` from a device
   shell and diff the constants against §1 (they may differ per model).
5. Cross-check the binding fields (`uci/hal` `model_name`, `.db` identity rows)
   to document the restore-time device check.

## 6. Scope note

`scripts/config_crypto/cfg_backup_tool.py` implements **info / decrypt /
inspect** only. Since AES-CBC is symmetric the full algorithm is documented
here (as any cryptanalysis writeup must), but this repo does not ship
re-encryption/repack tooling or any guidance on altering configurations —
that boundary is deliberate.

## 7. Defensive recommendations

1. **Treat `.cfg` backups as secret stores** (they contain Wi-Fi PSKs, login
   hashes, service credentials once decrypted — and the key is public). Store
   them encrypted at rest; delete when unneeded.
2. **Vendor fix**: MAC the backup (HMAC over the tar with a per-device key
   provisioned at manufacture), verify on restore; stop writing the md5 stub.
3. Restore path hardening (see `docs/WNC-CR200A_Web_Vulnerability_Audit.md`):
   strict parsing of every restored uci field; no eval/command sinks; enforce
   model/serial binding in code, not just UI.
4. Monitoring: config-restore events should be logged and alerted (they are
   semantically "privileged configuration change" on the gateway).

## 8. Sources

- OpenWrt forum "Adding Support for Verizon CR1000A" (spol-eff, 2023-03-17,
  p.10): complete pack/unpack script + `libmapi_backup.so` note; p.8: device
  `openssl enc -d` restore snippet + `get_encrypt_key` unwrapping.
- `MeisterLone/Verizon-CR1000A` → `Configs/CR1000A_V3.1.0.21_backup.cfg`
  (analysis input, §3) and `Firmware/`,`BootLogs/`.
- gorgias.me "Getting Root Access on Verizon FIOS-G1100" (2017-09-01):
  `getEncryptedBase64Backup()` = `EVP_aes_256_cbc` + Base64 lineage.
- `The5heepDev/FIOS-G1100` (`gwdecrypt.py`/`gwencrypt.py`).
- Verizon CR1000A user guide pp. 96–99 (Save & Restore; device-binding claim).
