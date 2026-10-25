# WNC-CR200A — FCC Internal Photos Analysis (FCC ID NKR-LV65C-T3)

Chip identification and test-point survey of the **Verizon Internet Gateway WNC-CR200A**
(Wistron NeWeb), based on the official FCC **Internal Photos** exhibit.

| Item | Value |
|---|---|
| Device | Verizon Internet Gateway WNC-CR200A (SKU WNC-CR200A, label photo (1)) |
| FCC ID | **NKR-LV65C-T3** (Grantee: Wistron NeWeb Corp.) |
| Exhibit | "22A0288R-Product Photos" (Internal Photos), DEKRA, 33 pages, photos (1)–(32) |
| Local file | `downloads/fcc/WNC-CR200A_FCC_Internal_Photos_6604463.pdf` |
| SHA-256 | `b4f60559d2e1097f23e2b56d53b879bbf340f1e503dfd9cd9636b6faea7d7b48` |
| Retrieved | 2026-10-25 via `.github/workflows/fetch-fcc-exhibits.yml` (doc id 6604463, committed to this branch) |

Page images (`downloads/fcc/internal_photos_pages/page01..33.jpg`, 150 dpi) and magnified
crops (`downloads/fcc/zooms/*.jpg`, 420–1300 dpi) were rendered from the PDF with PyMuPDF
for reading the package markings. Photo numbers below are the numbers printed on the
exhibit pages.

---

## 1. Board inventory

| Board | What it is | Key photos (page) |
|---|---|---|
| Main board ("48LV65CM_5G6 2023.03.17") | IPQ8072A host + Wi-Fi 6E + power + RF test row | (22)–(31), pp. 11–16 |
| 5G modem board (inside RF shield bay) | SDX65 modem-RF system | (17)–(21), pp. 9–10 |
| I/O board ("4B_LV55C1.5GF 2023/03/21", PCB "SH10 94V-0 E248779 2313 02-10") | rear I/O (2× RJ45, USB-C, 12 V DC barrel, reset) + 2× SPI NOR | (9)–(10), pp. 5 |
| LED/button daughterboard | front indicator LEDs + buttons, small MCU, JA1 header | (7)–(8), pp. 3–4 |
| Chassis/antenna | 5G + Wi-Fi antenna arrays, u.fl feeds (8 cellular + Wi-Fi ports per the Waveform port map: Ant1→J1/J5, Ant2→J3, Ant3→J2, Ant4→J4) | (25)–(27), (32), pp. 12–13, 17 |

---

## 2. Chip identification (the ask)

Markings are transcribed verbatim from the photo zooms; identifications are corroborated
against public datasheets/vendor listings where noted.

| # | Function | Marking (verbatim) | Identification | Where | Confidence |
|---|---|---|---|---|---|
| 1 | **Main SoC** (host CPU + Wi-Fi MAC) | `QUALCOMM IPQ8072A 000 / HH24583R` | **Qualcomm IPQ8072A** — IPQ807x "Hawkeye" Wi-Fi 6 SoC, 4× Cortex-A53, DDR3L/DDR4, eMMC 5.1, 2× USXGMII/SGMII (matches the OpenWrt IPQ807x target and Qualcomm's CR200A platform page) | photo (29), p. 15 (`p15_29_soc_only.jpg`) | **Confirmed** |
| 2 | System DRAM (SoC) | `2CR77 / D9BPK` + Micron logo, ×2 | **2× Micron memory devices** (DDR3L/DDR4 x16, 32-bit bus to the IPQ8072A). FBGA code `D9BPK` — public decoder tables are inconsistent (one lists an old mDDR part), so the exact P/N is **unresolved**; role (system RAM) is certain | photo (29), p. 15 (`z2_dram_one.jpg`) | Medium (role) / unresolved (P/N) |
| 3 | **Main flash — eMMC** | `SEC 31Q / KLMAG1JETD` | **Samsung KLMAG1JETD** 16 GB eMMC 5.1 (128 Gb) — OpenWrt rootfs/storage | photo (29), p. 15 (`p15_29_emmc_right.jpg`) | **Confirmed** |
| 4 | **Boot flash — SPI NOR ×2** | `WINBOND 25Q256 JV EQ` (+ date codes e.g. `2245A`) | **Winbond W25Q256JV** 256-Mbit (32 MB) SPI NOR, SOIC-8, two identical devices on the I/O board. Role inference: one boots the IPQ8072A (BL2/u-boot/env), one boots the SDX65 | photo (10), p. 5 (`z5_winbond.jpg`, `z2_winbond.jpg`) | **Confirmed** (part) / inferred (role) |
| 5 | **5G modem SoC** | `SDX65 101-AA` | **Qualcomm Snapdragon X65 (SDX65)** 5G NR/LTE modem-RF (matches Qualcomm's "Snapdragon X65 5G modem-RF" listing for the CR200A) | photo (17), p. 9 (`p09_17_modem_sdx65_ram.jpg`) | **Confirmed** |
| 6 | Modem PMIC | `PMX65 000 / P42708W7` | **Qualcomm PMX65** baseband PMIC (the documented PMX65 companion of SDX62/SDX65; also used as the iPhone 14–16 baseband PMU) | photo (17), p. 9 | **Confirmed** |
| 7 | Modem RAM + NAND (MCP) | `JSFC CA5QHAFGA / 1QDA343S / 213 405-A` | **JSC (Jeju Semiconductor) JSFCCA5QHAFGA-405A** MCP — 4 Gb ×8 SLC NAND + 4 Gb ×16 LPDDR4X (2133 MHz) in one 149-BGA (same MCP Quectel/SIMCom use on SDX62/SDX65 modules; JSC confirmed as supplier in Quectel's RG520N PCN) | photo (17), p. 9 (`z_jsfc_ram.jpg`) | **Confirmed** |
| 8 | 5G RF transceivers ×2 | `SDR735 001 / JE207R3F` | **Qualcomm SDR735** 5G NR/LTE RF transceiver (documented pairing for SDX62/SDX65) | photos (18)–(21), pp. 9–10 | **Confirmed** |
| 9 | **Wi-Fi 6E radio** | `QCN9074 001 / FK25T3N4` (lots `FR26…`) | **Qualcomm QCN9074** — tri-band (2.4/5/6 GHz) 4×4 802.11ax, PCIe Gen3, external-PA interfaces to 7.125 GHz | photos (28) p. 14, (31) p. 16 (`z_qcn_radio.jpg`, `z2_radio_p31.jpg`) | **Confirmed** |
| 10 | 6 GHz FEMs ×4 | `85784 / 0505A / 2305 CN` | **Skyworks SKY85784-11** Wi-Fi 6E high-power FEM (5.925–7.125 GHz, +19 dBm MCS11, 24-pin 3×5 mm) — the 6 GHz PA chains for the QCN9074 | photos (28) p. 14, (30) p. 15 (`z2_fems_row.jpg`, `z_fem_column.jpg`) | **Confirmed** |
| 11 | Wi-Fi front-end filters | modules `FTE1/FTE3/FTE5/FTE7` + metal-can filters ("431"-class chips) | Band-split filter/diplexer modules for the tri-band chains (exact module P/N not identified) | photo (31), p. 16 | Low (module ID) |
| 12 | **SoC PMIC** | `PMP8074 000-01 / PE2521N01` | **Qualcomm PMP8074** — the documented companion PMIC of the IPQ807x family (SPMI: rails, RTC, GPIOs; see OpenWrt IPQ807x target notes) | photo (30), p. 15 (`z5_pmic8074.jpg`) | **Confirmed** |
| 13 | Ethernet PHY | `QCA8072 000-01` | **Qualcomm QCA8072** dual-port 10/100/1000 Ethernet transceiver (PSGMII/QSGMII + SGMII), the standard IPQ807x companion PHY — serves the two rear RJ45 jacks | photo (30), p. 15 (`z5_qca_phy.jpg`) | **Confirmed** (marking) |
| 14 | Unidentified QFNs ×2 | designators `NCM6`, `NCM9`, near `TP_12V3` | Probably Ethernet magnetics-side drivers or a second PHY; markings not legible at available resolution | photo (29), p. 15 (`z3_phy29.jpg`) | Low |

Silkscreen identifiers seen on the boards: `48LV65CM_5G6 2023.03.17` (main board),
`4B_LV55C1.5GF 2023/03/21` and `SH10 94V-0 E248779 2313 02-10` (I/O board),
`5G8 EM` (RF section), `NSR 2312-1` (LAN magnetics modules).

---

## 3. Flash memory summary (the ask)

| Device | Type | Capacity | Function |
|---|---|---|---|
| Samsung KLMAG1JETD (`SEC 31Q`) | eMMC 5.1 | 16 GB | Main storage: bootloader stages, OpenWrt rootfs (the OSS release is OpenWrt 18.06-based), firmware, user data |
| Winbond W25Q256JV ×2 | SPI NOR, SOIC-8 | 2× 256 Mbit (2× 32 MB) | Boot flash: one per processor (IPQ8072A and SDX65) — classic Qualcomm "NOR boot + eMMC storage" split |
| JSC JSFCCA5QHAFGA-405A (MCP) | SLC NAND die + LPDDR4X die | 4 Gb NAND (512 MB) + 4 Gb LPDDR4X (512 MB) | Modem-local storage and modem RAM in one package (identical architecture to Quectel RG520N / SIMCom SIM8260 SDX62/SDX65 modules) |

System DRAM for the IPQ8072A is the pair of Micron `2CR77 / D9BPK` devices (see table #2).

---

## 4. Test points & UART/JTAG (the ask)

### 4.1 The labeled gold-pad row — photos (22) & (24), pp. 11–12

A row of **8 gold spring-contact pads** runs along the bottom edge of the main board,
directly under the gold-plated antenna/keep-out area. The two-line silkscreen is printed
rotated 180°; when oriented correctly the labels read (zoom: `z3_tp_labels_rot180.jpg`,
`z4_tp_left.jpg`, `z4_tp_right.jpg`):

```
XT-1   DE-2   XM-3   DE-4   XM-5   DE-6   XT-7   DE-8
```

- Even pads share the label **`DE`** (2, 4, 6, 8) → common return/ground of each pair.
- Odd pads alternate **`XT`** (1, 7) and **`XM`** (3, 5) → the four signal feeds.
- Layout = four (signal, return) pairs = **4× cellular MIMO chain conducted-test points**,
  consistent with the FCC "Tune Up Procedure" exhibit (conducted power calibration per
  antenna chain). This is the classic WNC arrangement for RF tune-up pads.

**These are RF test points, not digital debug ports** — no UART/JTAG naming anywhere.

### 4.2 JA1 debug header — photo (8), p. 4 (LED/button daughterboard)

- **`JA1`** — an unpopulated **2×3 pin-header footprint** (silkscreen "JA1"), the only
  header-style debug footprint in the whole photo set (`z4_hdr_p8.jpg`).
- Neighboring labeled pads on the same board: `TP_NOM_5V`, `TP_ADC_5V`, `TP_5VA`,
  `TP_SCL`, `TP_SDA`, `TP_GND` (supply + I²C monitoring for the LED/button MCU — a QFN
  MCU is visible at the board edge).
- **Best UART/JTAG candidate in the device**: a 6-pin 2×3 footprint is the usual shape of
  a JTAG/SWD or UART console header. On this daughterboard it most likely serves the
  local MCU (factory programming), not the IPQ8072A; probing is required to tell.

### 4.3 Power-rail test points (useful for any boot/debug work)

| Pad label | Location | Use |
|---|---|---|
| `TP_GND`, `TP_12V`, `TP_1V8`, `TP_2V5`, `TP_1V1` | main board, near eMMC (photo (29), p. 15) | rail monitoring |
| `TP_12V3` | main board, near NCM6/NCM9 (photo (29)) | 12 V / PoE-adjacent rail |
| `TP_NOM_5V`, `TP_ADC_5V`, `TP_5VA`, `TP_SCL`, `TP_SDA`, `TP_GND` | LED daughterboard (photo (8)) | supply + I²C |
| `TPE1` | RF bay near QCN9074 (photo (28)) | RF section (unidentified net) |

### 4.4 Verdict on UART/JTAG

1. **Nothing in the FCC Internal Photos is labeled UART, TX, RX, CONSOLE, TCK, TMS, TDI,
   TDO, or JTAG.** The schematics and "Operational Description" that would name the debug
   nets are filed under **Confidentiality** (permanently withheld), so a definitive
   pinout is not obtainable from the FCC record.
2. The hardware certainly *has* debug capability: the IPQ807x exposes multiple QUP
   UART/I²C/SPI BLSPs and JTAG, and the SDX65 has its own HS-UART debug.
3. **Practical probe order for anyone opening a unit**:
   - `JA1` (2×3) on the LED board — check for 3.3 V/1.8 V logic and a boot banner.
   - Unpopulated 4-pad clusters near the SoC/eMMC corner (photo (29) region) — typical
     location of a TP-out console; verify against GND with a scope during boot.
   - The `XT/DE/XM` row is RF-only — do **not** attach a serial adapter there.
   - eMMC is socketed-in-package (BGA); firmware extraction would be via ISP/SDIO or the
     boot NOR, not via any exposed header.

---

## 5. Method & artifacts (reproducibility)

1. PDF verified (SHA-256 above); pages are raster strips, so **`page.get_pixmap()` renders
   (not `get_images()` extraction)** are the correct way to view them.
2. Page renders at 150 dpi: `downloads/fcc/internal_photos_pages/page01..33.jpg`.
3. Magnified crops at 420–1300 dpi in `downloads/fcc/zooms/` — key files per finding:
   `p15_29_soc_only.jpg` (SoC), `p15_29_emmc_right.jpg` (eMMC + DRAM + TP labels),
   `p09_17_modem_sdx65_ram.jpg` + `z_jsfc_ram.jpg` (modem + MCP), `z5_winbond.jpg`
   (NOR), `z_qcn_radio.jpg` / `z2_radio_p31.jpg` (QCN9074), `z2_fems_row.jpg`
   (SKY85784 FEM row + PMP8074), `z5_pmic8074.jpg`, `z5_qca_phy.jpg`,
   `z3_tp_labels_rot180.jpg` / `z4_tp_left.jpg` / `z4_tp_right.jpg` (test-point row),
   `z4_hdr_p8.jpg` (JA1).
4. Corroboration sources: Qualcomm device page for the WNC-CR200A (Dragonwing NPro 6E +
   Snapdragon X65), OpenWrt IPQ807x target notes (PMP8074 PMIC, QCA8072/5 PHYs),
   Quectel RG520N PCN (JSFCCA5QHAFGA-405A = JSC MCP), Skyworks/QCN9074 public datasheets.

## 6. Related files in this repo

- `downloads/fcc/WNC-CR200A_FCC_Internal_Photos_6604463.pdf` — the exhibit itself.
- `.github/workflows/fetch-fcc-exhibits.yml` — re-download/verify/commit tooling (5 mirrors).
- `docs/WNC-CR200A_Open_Source_Disclosure.md`, `manifest/` — the Verizon OSS release for
  the same device (OpenWrt 18.06-based, 93 packages) — useful cross-reference for what the
  IPQ8072A/SDX65 firmware actually runs.
