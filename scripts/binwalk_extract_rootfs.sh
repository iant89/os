#!/usr/bin/env bash
# Extract a root filesystem (and /etc/init.d + web configs) from a firmware
# image using binwalk.  Written for Verizon gateway firmware (WNC-CR200A and
# the shared IPQ807x/VZSDK family), but works on any image binwalk understands.
#
# Usage:   binwalk_extract_rootfs.sh <firmware-image> [output-dir]
# Needs:   binwalk (>= 2.3), squashfs-tools (unsquashfs), cpio, gzip, xz
#
# The image is carved with `binwalk -e -M` (recursive).  SquashFS/cpio payloads
# are unpacked automatically; anything extracted to <output-dir>/rootfs*/ is a
# root filesystem candidate.  Collected boot/web files land in <output-dir>/collected/.
set -uo pipefail

IMG="${1:?usage: $0 <firmware-image> [output-dir]}"
OUT="${2:-${IMG%.*}_extracted}"
COLLECT="$OUT/collected"

mkdir -p "$OUT" "$COLLECT"

echo "==> binwalk signature scan: $IMG"
binwalk "$IMG" | tee "$OUT/binwalk_scan.txt"

echo "==> recursive extraction (binwalk -e -M)"
IMG_ABS="$(cd "$(dirname "$IMG")" && pwd)/$(basename "$IMG")"
( cd "$OUT" && binwalk -e -M "$IMG_ABS" > binwalk_extract.log 2>&1 ) || true

echo "==> unpacking any carved cpio archives"
while IFS= read -r cpio_file; do
  dest="${cpio_file%.cpio}-root"
  [ -d "$dest" ] && continue
  mkdir -p "$dest"
  if command -v cpio >/dev/null 2>&1; then
    (cd "$dest" && cpio -idm --quiet < "../$(basename "$cpio_file")" 2>/dev/null) || true
  else
    here="$(cd "$(dirname "$0")" && pwd)"
    python3 "$here/extract_cpio.py" "$cpio_file" "$dest" || true
  fi
done < <(find "$OUT" -name '*.cpio' -type f 2>/dev/null)

echo "==> collecting /etc/init.d scripts, preinit and web server configs"
find "$OUT" -type f \( \
    -path '*/etc/init.d/*' -o -name 'preinit' -o -name 'inittab' -o \
    -name 'rc.common' -o -name 'rc.func' -o -path '*/etc/config/*' -o \
    -iname '*uhttpd*' -o -iname '*lighttpd*' -o -iname '*nginx*' -o \
    -iname '*goahead*' -o -iname '*thttpd*' -o -name 'passwd' -o -name 'group' \
  \) 2>/dev/null | while IFS= read -r f; do
    rel="${f#$OUT/}"
    mkdir -p "$COLLECT/$(dirname "$rel")"
    cp "$f" "$COLLECT/$rel"
  done

echo "==> done."
echo "    scan log : $OUT/binwalk_scan.txt"
echo "    extracted: $OUT/"
echo "    collected: $COLLECT/  (init.d scripts, preinit, web configs)"
find "$COLLECT" -type f | head -40
