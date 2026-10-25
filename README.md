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
