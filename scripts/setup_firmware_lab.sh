#!/usr/bin/env bash
# setup_firmware_lab.sh — provision an offline-capable firmware analysis machine.
#
# Target: Debian 12 / Ubuntu 22.04+ x86_64 (a VM is fine — see Vagrantfile and
# scripts/build_lab_vm_qemu.sh).  Installs: binwalk 2.3.3, unblob, jefferson,
# ubi-reader, yaffshiv, sasquatch, firmware-mod-kit, Ghidra 12.2, serial-console
# tools, and udev rules for CP2102/FT232 UART adapters.
#
# Usage:
#   sudo scripts/setup_firmware_lab.sh                 # online install
#   sudo scripts/setup_firmware_lab.sh --bundle DIR    # offline install from a
#                                                      # bundle made by
#                                                      # build_firmware_lab_bundle.sh
#   scripts/setup_firmware_lab.sh --check              # verify an existing install
#
# Options:
#   --bundle DIR    install only from DIR (no network); expects manifest files + pip/
#   --check         verify tools and exit
#   --no-apt        skip apt-get (assumes packages present)
#   --skip-ghidra   skip the 570 MB Ghidra download/install
#   --prefix DIR    install root (default /opt/firmware-lab; use $HOME/firmware-lab
#                   for a no-sudo install of the tools; apt/udev steps still need sudo)
set -euo pipefail

LAB_PREFIX="/opt/firmware-lab"
BUNDLE=""
DO_CHECK=0; DO_APT=1; DO_GHIDRA=1
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle) BUNDLE="$2"; shift 2 ;;
    --check) DO_CHECK=1; shift ;;
    --no-apt) DO_APT=0; shift ;;
    --skip-ghidra) DO_GHIDRA=0; shift ;;
    --prefix) LAB_PREFIX="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

VENV="$LAB_PREFIX/venv"
BIN="$LAB_PREFIX/bin"
SRC="$LAB_PREFIX/src"
GHIDRA_ROOT="/opt/ghidra"
MANIFEST="$REPO_ROOT/manifest/firmware-lab-tools.json"
[ -f "$MANIFEST" ] || MANIFEST="$BUNDLE/manifest/firmware-lab-tools.json"

say() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
SUDO=""
[ "$(id -u)" -ne 0 ] && { have sudo && SUDO="sudo" || { echo "need root or sudo"; exit 1; }; }

# ---------------------------------------------------------------------------
check_install() {
  say "verifying firmware lab install (prefix: $LAB_PREFIX)"
  local fail=0
  check() { # name, command-or-path, [version-args]
    local cmd="$2"
    if have "$cmd" || [ -x "$cmd" ]; then
      printf '  OK    %-22s' "$1"
      if [ $# -ge 3 ]; then "$cmd" $3 2>&1 | head -1; else echo; fi
    else printf '  MISS  %-22s\n' "$1"; fail=1; fi
  }
  [ -d "$VENV" ] && echo "  OK    python venv           $VENV" || { echo "  MISS  python venv"; fail=1; }
  check binwalk "$VENV/bin/binwalk" "--help"
  check unblob "$VENV/bin/unblob" "--version"
  check jefferson "$VENV/bin/jefferson" "--help"
  check ubireader_extract_files "$VENV/bin/ubireader_extract_files" "--help"
  check sasquatch "$BIN/sasquatch"
  check yaffshiv "$BIN/yaffshiv"
  [ -d "$SRC/firmware-mod-kit" ] && echo "  OK    firmware-mod-kit      $SRC/firmware-mod-kit" || { echo "  MISS  firmware-mod-kit"; fail=1; }
  if [ -e "$GHIDRA_ROOT/current/support/analyzeHeadless" ]; then
    echo "  OK    ghidra               $GHIDRA_ROOT/current"
  else echo "  MISS  ghidra               (run without --skip-ghidra)"; fail=1; fi
  for t in picocom minicom tio screen stty; do have "$t" && printf '  OK    %-22s\n' "$t" || { printf '  MISS  %-22s\n' "$t"; fail=1; }; done
  [ -f /etc/udev/rules.d/99-firmware-lab-serial.rules ] && echo "  OK    udev serial rules" || { echo "  MISS  udev serial rules"; fail=1; }
  echo
  if [ $fail -eq 0 ]; then echo "All checks passed. Lab ready."; else echo "Some components missing — re-run without --check (see warnings)."; fi
  return $fail
}

[ "$DO_CHECK" -eq 1 ] && { check_install; exit $?; }

# ---------------------------------------------------------------------------
if [ "$DO_APT" -eq 1 ]; then
  say "installing apt packages"
  if [ -n "$BUNDLE" ] && ls "$BUNDLE"/debs/*.deb >/dev/null 2>&1; then
    # fully offline: install the cached .debs
    $SUDO dpkg -i "$BUNDLE"/debs/*.deb || $SUDO apt-get -f install -y --no-download || true
  else
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq build-essential cmake pkg-config git curl ca-certificates \
      python3 python3-pip python3-venv python3-dev zlib1g-dev liblzma-dev liblzo2-dev \
      uuid-dev libssl-dev squashfs-tools mtd-utils u-boot-tools cpio lzop p7zip-full \
      unzip file xxd hexedit bsdextrautils kmod usbutils udev minicom picocom tio screen
    # JDK for Ghidra (21 preferred, 17 acceptable for older builds)
    $SUDO apt-get install -y -qq openjdk-21-jdk-headless || \
      $SUDO apt-get install -y -qq openjdk-17-jdk-headless || \
      warn "no JDK installed — Ghidra needs JDK 21+"
  fi
fi

# ---------------------------------------------------------------------------
say "creating python venv + tool dirs"
$SUDO mkdir -p "$BIN" "$SRC"
if [ ! -d "$VENV" ]; then
  [ -w "$(dirname "$LAB_PREFIX")" ] || $SUDO mkdir -p "$LAB_PREFIX"
  [ -w "$LAB_PREFIX" ] || $SUDO chown "$USER" "$LAB_PREFIX" 2>/dev/null || true
  python3 -m venv "$VENV"
fi
P="$VENV/bin/pip"
$P install -q --upgrade pip wheel setuptools

fetch() { # file url sha256 dest
  local f="$1" url="$2" sha="$3" dest="$4"
  if [ -n "$BUNDLE" ] && [ -f "$BUNDLE/$f" ]; then
    cp "$BUNDLE/$f" "$dest"
  else
    echo "  downloading $url"
    curl -fL --retry 3 --max-time 1200 -o "$dest" "$url"
  fi
  if [ -n "$sha" ]; then
    echo "$sha  $dest" | sha256sum -c - >/dev/null || { echo "SHA256 mismatch for $f" >&2; exit 1; }
    echo "  verified sha256 $f"
  fi
}

# ---------------------------------------------------------------------------
say "installing python extraction tools (unblob, jefferson, ubi-reader) + binwalk"
if [ -n "$BUNDLE" ]; then
  $P install -q --no-index --find-links "$BUNDLE/pip" unblob==26.6.4 jefferson==0.4.8 ubi-reader==0.8.16
else
  $P install -q unblob==26.6.4 jefferson==0.4.8 ubi-reader==0.8.16
fi
fetch binwalk-2.3.3.tar.gz \
  "https://codeload.github.com/ReFirmLabs/binwalk/tar.gz/refs/tags/v2.3.3" \
  "7e32b94dc77632b51d18732b5456e2a3ef85e4521d7d4a54410e36f93859501f" "$SRC/binwalk-2.3.3.tar.gz"
$P install -q "$SRC/binwalk-2.3.3.tar.gz"

# ---------------------------------------------------------------------------
say "building sasquatch (patched unsquashfs)"
fetch sasquatch-b34aa5ef.tar.gz \
  "https://codeload.github.com/onekey-sec/sasquatch/tar.gz/b34aa5ef67068a2137ac04e2272915bd45388260" \
  "74844a1d9be50da108e9b37734414ef252f7aaf97ea0b3cf3f1e814046d4c9e0" "$SRC/sasquatch.tar.gz"
rm -rf "$SRC/sasquatch"; mkdir -p "$SRC/sasquatch"
tar -xf "$SRC/sasquatch.tar.gz" -C "$SRC/sasquatch" --strip-components=1
( cd "$SRC/sasquatch" && ./build.sh >/dev/null 2>&1 || make -j"$(nproc)" >/dev/null 2>&1 ) && \
  cp "$SRC/sasquatch/sasquatch" "$BIN/sasquatch" && echo "  sasquatch -> $BIN/sasquatch" || \
  warn "sasquatch build failed (non-fatal; stock unsquashfs + unblob still work)"

# ---------------------------------------------------------------------------
say "installing yaffshiv"
fetch yaffshiv-a8f21283.tar.gz \
  "https://codeload.github.com/onekey-sec/yaffshiv/tar.gz/a8f21283c25057740371fd34e9b6f3c4771375f1" \
  "4fa34f0612f2f938cab7f30e3a0208005c199b917997af304215c9db0c5ca0fa" "$SRC/yaffshiv.tar.gz"
rm -rf "$SRC/yaffshiv"; mkdir -p "$SRC/yaffshiv"
tar -xf "$SRC/yaffshiv.tar.gz" -C "$SRC/yaffshiv" --strip-components=1
cp "$SRC/yaffshiv/yaffshiv.py" "$BIN/yaffshiv" && chmod +x "$BIN/yaffshiv"

# ---------------------------------------------------------------------------
say "installing firmware-mod-kit (legacy; build best-effort)"
fetch firmware-mod-kit-c72f45d7.tar.gz \
  "https://codeload.github.com/rampageX/firmware-mod-kit/tar.gz/c72f45d7a062156125ae00cb867d8a614b50b963" \
  "c6797d02445a0ff3dc764fd1b82b932ef5a20110fef35ab6d158581101769184" "$SRC/firmware-mod-kit.tar.gz"
rm -rf "$SRC/firmware-mod-kit"; mkdir -p "$SRC/firmware-mod-kit"
tar -xf "$SRC/firmware-mod-kit.tar.gz" -C "$SRC/firmware-mod-kit" --strip-components=1
( cd "$SRC/firmware-mod-kit" && make >/dev/null 2>&1 ) && echo "  firmware-mod-kit built" || \
  warn "firmware-mod-kit build failed (common on new gcc — use unblob; scripts extract-firmware.sh/patch-firmware.sh still available)"

# ---------------------------------------------------------------------------
if [ "$DO_GHIDRA" -eq 1 ]; then
  say "installing Ghidra 12.2 -> $GHIDRA_ROOT"
  fetch ghidra_12.2_PUBLIC_20261016.zip \
    "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.2_build/ghidra_12.2_PUBLIC_20261016.zip" \
    "2c2cd776db3c1f6a097ba418922378ac3649cadd5e844a6f5f088ae628a7be67" "$SRC/ghidra.zip"
  $SUDO mkdir -p "$GHIDRA_ROOT"
  $SUDO unzip -q -o "$SRC/ghidra.zip" -d "$GHIDRA_ROOT"
  $SUDO ln -sfn "$GHIDRA_ROOT"/ghidra_*_PUBLIC "$GHIDRA_ROOT/current"
  printf '#!/bin/sh\nexec %s/current/support/analyzeHeadless "$@"\n' "$GHIDRA_ROOT" | $SUDO tee "$BIN/ghidra-headless" >/dev/null
  $SUDO chmod +x "$BIN/ghidra-headless"
  echo "  GUI: $GHIDRA_ROOT/current/ghidraRun   headless: ghidra-headless"
fi

# ---------------------------------------------------------------------------
say "installing UART udev rules + group membership"
if [ -f "$REPO_ROOT/udev/99-firmware-lab-serial.rules" ]; then
  $SUDO cp "$REPO_ROOT/udev/99-firmware-lab-serial.rules" /etc/udev/rules.d/
  $SUDO udevadm control --reload-rules 2>/dev/null || true
  $SUDO udevadm trigger 2>/dev/null || true
fi
for g in dialout plugdev; do getent group "$g" >/dev/null && $SUDO usermod -aG "$g" "$USER" || true; done
echo "  log out/in for group changes to take effect"

# ---------------------------------------------------------------------------
say "environment notes"
cat <<EOF
  Add to ~/.bashrc (or use full paths):
    export PATH="$VENV/bin:$BIN:\$PATH"
  Serial console:      scripts/uart_connect.sh [/dev/firmware-uart] [baud]
  Boot-log capture:    scripts/uart_boot_capture.sh   (power-cycle the device)
  Firmware carving:    scripts/binwalk_extract_rootfs.sh <image> [outdir]
  Offline re-install:  scripts/build_firmware_lab_bundle.sh  (on a net-connected host)
EOF

check_install || true
