#!/usr/bin/env bash
# enum_hidden_endpoints.sh — hidden URL / undocumented API enumerator for the
# WNC-CR200A admin UI (or lab VM proxying to it). Authorized testing only.
#
# Usage:  enum_hidden_endpoints.sh https://192.168.1.1
#   env:  USERID / PASSWD  = admin creds (for the ubus object listing, optional)
#   env:  OUTDIR           = output dir (default ./hidden-enum-<timestamp>)
# Output: routes_found.txt (SPA + cgi names from JS), probe_results.txt,
#         ubus_objects.txt, js/ (downloaded bundles for manual review).
set -u
BASE="${1:?usage: $0 https://<router-ip>}"
OUT="${OUTDIR:-hidden-enum-$(date +%Y%m%d-%H%M%S)}"
WL="$(dirname "$0")/hidden_paths.txt"
mkdir -p "$OUT/js"
BASE="${BASE%/}"
echo "[*] target: $BASE  output: $OUT"

hdr() { printf '\n==== %s ====\n' "$1" | tee -a "$OUT/summary.txt"; }

# ---- 1. SPA shell + JS bundle harvest --------------------------------------
hdr "1. SPA shell + JS bundle route extraction"
curl -ksS --max-time 15 "$BASE/" -o "$OUT/index.html" || echo "[!] fetch / failed"
grep -oE 'src="[^"]+\.js[^"]*"' "$OUT/index.html" 2>/dev/null | sed 's/src="//;s/"$//' | sort -u > "$OUT/js_urls.txt"
# also catch chunked/cdn-style bundles referenced from bundles
: > "$OUT/routes_found.txt"
while read -r u; do
  [ -z "$u" ] && continue
  case "$u" in http*) url="$u";; /*) url="$BASE$u";; *) url="$BASE/$u";; esac
  f="$OUT/js/$(basename "${u%%\?*}")"
  curl -ksS --max-time 20 "$url" -o "$f" 2>/dev/null || continue
  # SPA hash routes, /cgi/ names, ubus object.method strings
  grep -oE '#/[A-Za-z0-9_./-]+' "$f" 2>/dev/null >> "$OUT/routes_found.txt"
  grep -oE '/cgi/[A-Za-z0-9_.-]+' "$f" 2>/dev/null >> "$OUT/routes_found.txt"
  grep -oE '"(arc|zarc|luci|system|file|session|uci)[A-Za-z0-9_.-]*"\s*,\s*"[A-Za-z0-9_.-]+"' "$f" 2>/dev/null >> "$OUT/routes_found.txt"
done < "$OUT/js_urls.txt"
sort -u "$OUT/routes_found.txt" -o "$OUT/routes_found.txt"
echo "[*] $(wc -l < "$OUT/routes_found.txt") route/API strings -> $OUT/routes_found.txt"
head -40 "$OUT/routes_found.txt"

# ---- 2. wordlist probe ------------------------------------------------------
hdr "2. wordlist probe (codes != 404/000)"
: > "$OUT/probe_results.txt"
while read -r p; do
  case "$p" in ''|\#*) continue;; esac
  url="$BASE$p"
  out=$(curl -ksS --max-time 8 -o /dev/null -w '%{http_code} %{size_download} %{redirect_url}' "$url" 2>/dev/null) || out="000 0 -"
  code="${out%% *}"
  case "$code" in 404|000) ;; *) printf '%s\t%s\n' "$out" "$p" | tee -a "$OUT/probe_results.txt";; esac
done < "$WL"
echo "[*] $(wc -l < "$OUT/probe_results.txt") non-404 hits"

# ---- 3. ubus object inventory (undocumented API surface) --------------------
hdr "3. ubus object listing (admin session)"
if [ -n "${USERID:-}" ] && [ -n "${PASSWD:-}" ]; then
  login=$(curl -ksS --max-time 8 -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"call","params":["00000000000000000000000000000000","session","login","username":"'"$USERID"'","password":"'"$PASSWD"'"]}' \
    "$BASE/ubus")
  sid=$(printf '%s' "$login" | grep -oE '[0-9a-f]{32}' | head -1)
  if [ -n "$sid" ]; then
    echo "[*] session ok: $sid"
    curl -ksS --max-time 8 -H 'Content-Type: application/json' \
      -d '{"jsonrpc":"2.0","id":2,"method":"list","params":["'"$sid"'","*"]}' \
      "$BASE/ubus" | tee "$OUT/ubus_objects.txt"
  else
    echo "[!] login failed (check USERID/PASSWD)" | tee -a "$OUT/ubus_objects.txt"
  fi
else
  echo "[*] set USERID/PASSWD to enumerate /ubus objects" | tee "$OUT/ubus_objects.txt"
fi

# ---- 4. shell-adjacent ports -----------------------------------------------
hdr "4. telnet/tftp port check"
HOST="${BASE#*://}"; HOST="${HOST%%/*}"
for port in 21 23 69 2323; do
  (exec 3<>"/dev/tcp/${HOST}/$port") >/dev/null 2>&1 && echo "OPEN tcp/$port" | tee -a "$OUT/ports.txt" || echo "closed tcp/$port"
done

echo
echo "[*] done. review $OUT/{summary.txt,routes_found.txt,probe_results.txt,ubus_objects.txt} and $OUT/js/"
