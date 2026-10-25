#!/usr/bin/env bash
set -euo pipefail

# Fetches the GitHub-mirrored OpenWrt & userspace firmware components
# specified in Verizon's WNC-CR200A Open Source Disclosure (Release 3.2.0.13)
# and pins each component to the commit matching its disclosed version/date.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENTS_DIR="${ROOT_DIR}/src/components"
mkdir -p "${COMPONENTS_DIR}"

fetch_component() {
  local name="$1"
  local repo_url="$2"
  local cutoff_date="$3"
  local target_dir="${COMPONENTS_DIR}/${name}"

  echo "==> Fetching ${name} (${repo_url}, cutoff <= ${cutoff_date})..."
  rm -rf "${target_dir}"
  git clone --quiet "${repo_url}" "${target_dir}"

  pushd "${target_dir}" >/dev/null
  local commit_sha
  commit_sha="$(git rev-list -n 1 --before="${cutoff_date} 23:59:59 UTC" HEAD || true)"
  if [[ -n "${commit_sha}" ]]; then
    git checkout --quiet "${commit_sha}"
    echo "    Pinned ${name} at commit ${commit_sha:0:12} ($(git show -s --format='%ci - %s' HEAD))"
  else
    echo "    Kept HEAD ($(git show -s --format='%ci - %s' HEAD))"
  fi
  rm -rf .git
  popd >/dev/null
}

fetch_component "fwtool"        "https://github.com/openwrt/fwtool.git"        "2020-05-25"
fetch_component "cgi-io"        "https://github.com/openwrt/cgi-io.git"        "2020-08-01"
fetch_component "fstools"       "https://github.com/openwrt/fstools.git"       "2020-05-12"
fetch_component "libiwinfo"     "https://github.com/openwrt/iwinfo.git"        "2019-10-16"
fetch_component "jsonfilter"    "https://github.com/openwrt/jsonpath.git"      "2018-02-04"
fetch_component "libnl-tiny"    "https://github.com/openwrt/libnl-tiny.git"    "2020-05-25"
fetch_component "librpc"        "https://github.com/openwrt/librpc-uclibc.git" "2015-11-04"
fetch_component "libubox"       "https://github.com/openwrt/libubox.git"       "2020-05-25"
fetch_component "netifd"        "https://github.com/openwrt/netifd.git"        "2019-08-05"
fetch_component "opkg-lede"     "https://github.com/openwrt/opkg-lede.git"     "2020-05-25"
fetch_component "mcproxy"       "https://github.com/mcproxy/mcproxy.git"       "2017-08-24"

echo "==> All GitHub-hosted firmware components fetched into ${COMPONENTS_DIR}"
