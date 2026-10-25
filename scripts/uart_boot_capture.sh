#!/usr/bin/env bash
# Capture the boot console output of a device under test over UART while YOU
# power-cycle it.  Tries the common baud rates and saves one log per rate so the
# right one can be identified (the one showing a readable U-Boot banner).
#
# Usage: uart_boot_capture.sh [device] [seconds] [baud1,baud2,...]
#   device   default /dev/firmware-uart -> /dev/ttyUSB0
#   seconds  capture window per baud rate, default 30
#   bauds    default 115200,57600,38400,9600,230400
#
# Run this, then power-cycle the router when prompted.  Stop early with Ctrl-C;
# partial logs are kept.
set -uo pipefail

DEV="${1:-/dev/firmware-uart}"
SECS="${2:-30}"
BAUDS="${3:-115200,57600,38400,9600,230400}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/logs/uart"
mkdir -p "$OUT"

[ -e "$DEV" ] || DEV=/dev/ttyUSB0
[ -e "$DEV" ] || { echo "error: no serial device found" >&2; exit 1; }

echo "==> capturing $DEV for ${SECS}s per baud rate: $BAUDS"
echo "==> logs in $OUT/boot-*"

for baud in ${BAUDS//,/ }; do
    log="$OUT/boot-${baud}-$(date +%Y%m%d-%H%M%S).log"
    echo
    echo "---- baud $baud : power-cycle the device NOW (window ${SECS}s) ----"
    stty -F "$DEV" "$baud" cs8 -cstopb -parenb -ixon -ixoff -icanon -echo raw 2>/dev/null || {
        echo "     stty failed on $DEV — is another program holding the port?"; continue; }
    timeout --foreground "$SECS" cat "$DEV" > "$log" 2>/dev/null || true
    # normalise CR/LF and strip ANSI escapes for grep-ability
    sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\r$//' "$log" > "${log%.log}.clean" 2>/dev/null || true
    if grep -qiE 'u-boot|bootloader|kernel|hit any key|autoboot|linux version' "${log%.log}.clean" 2>/dev/null; then
        echo "     >>> console detected at $baud (see ${log%.log}.clean)"
        grep -iE 'u-boot|bootloader|hit any key|autoboot|linux version|openwrt|chaos' "${log%.log}.clean" | head -5
    else
        echo "     nothing recognizable at $baud"
    fi
done

echo
echo "==> done. Inspect $OUT/boot-*.clean — the readable one is your console speed"
echo "    (then: scripts/uart_connect.sh $DEV <baud>)"
