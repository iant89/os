#!/usr/bin/env bash
# build_firmware_lab_bundle.sh — run this ONCE on an internet-connected machine
# to collect every pinned lab artifact into a single directory/tarball that can be
# transferred to an air-gapped analysis VM and installed with:
#
#     sudo scripts/setup_firmware_lab.sh --bundle /path/to/firmware-lab-bundle
#
# Usage: build_firmware_lab_bundle.sh [output-dir] [--skip-ghidra]
#   default output: ./firmware-lab-bundle
set -euo pipefail

OUT="firmware-lab-bundle"
SKIP_GHIDRA=0
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-ghidra) SKIP_GHIDRA=1; shift ;;
    *) OUT="$1"; shift ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_ROOT/manifest/firmware-lab-tools.json"
PY=python3

[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }
mkdir -p "$OUT/pip"

echo "==> downloading pinned tools into $OUT"
"$PY" - "$MANIFEST" "$OUT" "$SKIP_GHIDRA" <<'EOF'
import json, subprocess, sys, os
manifest, out, skip_ghidra = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
tools = json.load(open(manifest))["tools"]
for t in tools:
    if skip_ghidra and t["name"] == "ghidra":
        print(f"  skip  {t['file']}  (--skip-ghidra)")
        continue
    dest = os.path.join(out, t["file"])
    if os.path.exists(dest):
        print(f"  have  {t['file']}")
        continue
    print(f"  get   {t['file']}  ({t.get('size', '?')} bytes)")
    subprocess.run(["curl", "-fL", "--retry", "3", "--max-time", "3600",
                    "-o", dest, t["url"]], check=True)
EOF

echo "==> verifying sha256 of every artifact"
( cd "$OUT" && "$PY" - "$MANIFEST" "$SKIP_GHIDRA" <<'EOF'
import json, hashlib, sys, os
manifest, skip_ghidra = sys.argv[1], sys.argv[2] == "1"
ok = True
for t in json.load(open(manifest))["tools"]:
    if not os.path.exists(t["file"]):
        print(f"  --  {t['file']}  (not bundled)")
        continue
    h = hashlib.sha256(open(t["file"], "rb").read()).hexdigest()
    status = "OK " if h == t["sha256"] else "BAD"
    if h != t["sha256"]:
        ok = False
    print(f"  {status} {t['file']}  {h}")
sys.exit(0 if ok else 1)
EOF
)

echo "==> downloading pip dependency closure (unblob, jefferson, ubi-reader)"
"$PY" -m pip download -q -d "$OUT/pip" unblob==26.6.4 jefferson==0.4.8 ubi-reader==0.8.16
echo "  $(ls "$OUT/pip" | wc -l) wheels/sdists"

echo "==> downloading apt .debs for offline dpkg install (needs sudo; skipped if apt unusable)"
if command -v apt-get >/dev/null 2>&1; then
  mkdir -p "$OUT/debs"
  APT_PKGS=$( "$PY" - "$MANIFEST" <<'EOF'
import json, sys
print(" ".join(json.load(open(sys.argv[1]))["apt_packages"]))
EOF
)
  if sudo apt-get install -y --download-only -o Dir::Cache::archives="$PWD/$OUT/debs" $APT_PKGS >/dev/null 2>&1; then
    rm -f "$OUT/debs/lock"; rmdir "$OUT/debs/partial" 2>/dev/null || true
    echo "  $(ls "$OUT/debs"/*.deb 2>/dev/null | wc -l) .deb packages cached"
  else
    echo "  WARNING: apt .deb download failed (wrong distro / no apt lists) —" >&2
    echo "           offline installs will still need these packages present" >&2
  fi
else
  echo "  (no apt-get on this host — skipping .deb cache)"
fi

echo "==> copying installer + udev rules + manifest"
cp "$REPO_ROOT/scripts/setup_firmware_lab.sh" "$OUT/"
mkdir -p "$OUT/udev" "$OUT/manifest"
cp "$REPO_ROOT/udev/99-firmware-lab-serial.rules" "$OUT/udev/"
cp "$MANIFEST" "$OUT/manifest/"

echo "==> writing SHA256SUMS"
( cd "$OUT" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )

STAMP="$(date +%Y%m%d)"
TARBALL="firmware-lab-bundle-$STAMP.tar.gz"
tar -czf "$TARBALL" -C "$(dirname "$OUT")" "$(basename "$OUT")"
echo
echo "==> done: $TARBALL  ($(du -h "$TARBALL" | cut -f1))"
echo "    Copy to the analysis VM and run:"
echo "      tar xzf $(basename "$TARBALL") && sudo firmware-lab-bundle/setup_firmware_lab.sh --bundle firmware-lab-bundle"
