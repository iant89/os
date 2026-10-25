#!/usr/bin/env bash
set -euo pipefail

# Official Verizon Open Source Portal URLs for the Verizon Internet Gateway (WNC-CR200A)
PORTAL_URL="https://www.verizon.com/support/residential/internet/equipment/open-source-software"
GPL_ZIP_URL="https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/WNC-CR200A_gpl_release_3.2.0.13.zip"
DISCLOSURE_PDF_URL="https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/WNC-CR200A_Open_Source_Resource_3.2.0.13.pdf"
VZSDK_PDF_URL="https://www.verizon.com/content/dam/verizon/support/consumer/documents/open-source/Verizon-Fios-Router-(G3100-CR1000A-CR1000B)-additional-open-source-disclosures-for-VZSDK-Container.pdf"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_DIR="${ROOT_DIR}/downloads"
EXTRACT_DIR="${ROOT_DIR}/src/gpl_release_3.2.0.13"

mkdir -p "${DOWNLOAD_DIR}"

USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

download_file() {
  local url="$1"
  local dest="$2"
  echo "==> Downloading: $(basename "${dest}")"
  echo "    URL: ${url}"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 -C - -A "${USER_AGENT}" -e "${PORTAL_URL}" -o "${dest}" "${url}"
  elif command -v wget >/dev/null 2>&1; then
    wget -c --tries=3 --user-agent="${USER_AGENT}" --referer="${PORTAL_URL}" -O "${dest}" "${url}"
  else
    echo "Error: Neither curl nor wget is installed." >&2
    exit 1
  fi
}

echo "========================================================================"
echo " Verizon Internet Gateway (WNC-CR200A) Official Open Source Downloader"
echo " Portal: ${PORTAL_URL}"
echo "========================================================================"

# 1. Download Open Source Disclosure PDF
download_file "${DISCLOSURE_PDF_URL}" "${DOWNLOAD_DIR}/WNC-CR200A_Open_Source_Resource_3.2.0.13.pdf"

# 2. Download VZSDK Container Open Source Disclosure PDF
download_file "${VZSDK_PDF_URL}" "${DOWNLOAD_DIR}/VZSDK_Container_Open_Source_Disclosure.pdf" || true

# 3. Download Official WNC-CR200A GPL Source Release ZIP
GPL_ZIP_PATH="${DOWNLOAD_DIR}/WNC-CR200A_gpl_release_3.2.0.13.zip"
download_file "${GPL_ZIP_URL}" "${GPL_ZIP_PATH}"

echo "==> Verifying ZIP archive integrity..."
if command -v unzip >/dev/null 2>&1; then
  unzip -t "${GPL_ZIP_PATH}" >/dev/null
  echo "==> Extracting GPL release into ${EXTRACT_DIR} ..."
  mkdir -p "${EXTRACT_DIR}"
  unzip -q -o "${GPL_ZIP_PATH}" -d "${EXTRACT_DIR}"
  echo "==> Extraction complete: ${EXTRACT_DIR}"
else
  echo "Warning: 'unzip' not found; archive saved at ${GPL_ZIP_PATH}"
fi

echo "==> Done."
