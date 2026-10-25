#!/usr/bin/env bash
# Open a serial console to the device under test (e.g., WNC-CR200A JA1 header).
#
# Usage: uart_connect.sh [device] [baud]
#   device  default: /dev/firmware-uart (udev symlink), falls back to /dev/ttyUSB0
#   baud    default: 115200  (U-Boot consoles on IPQ807x-class boards are 115200 8N1)
#
# Uses the first available of: tio, picocom, minicom, screen.
set -uo pipefail

DEV="${1:-/dev/firmware-uart}"
BAUD="${2:-115200}"
LOGDIR="$(cd "$(dirname "$0")/.." && pwd)/logs/uart"

[ -e "$DEV" ] || DEV=/dev/ttyUSB0
if [ ! -e "$DEV" ]; then
    echo "error: $DEV not found. Plug in the adapter; check 'dmesg | tail' and" >&2
    echo "       'ls -l /dev/firmware-uart /dev/ttyUSB*'. Is the udev rule installed?" >&2
    exit 1
fi
[ -r "$DEV" ] && [ -w "$DEV" ] || {
    echo "error: no rw permission on $DEV — add yourself to the dialout group:" >&2
    echo "       sudo usermod -aG dialout \$USER   (then log out/in)" >&2
    exit 1
}

mkdir -p "$LOGDIR"
echo "==> $DEV @ ${BAUD} 8N1  (log: $LOGDIR/session-$(date +%Y%m%d-%H%M%S).log)"
echo "    exit tio: Ctrl-t q | picocom: Ctrl-a Ctrl-x | minicom: Ctrl-a x | screen: Ctrl-a k"

if command -v tio >/dev/null 2>&1; then
    exec tio -b "$BAUD" -d 8 -p none -s 1 --log --log-dir "$LOGDIR" "$DEV"
elif command -v picocom >/dev/null 2>&1; then
    exec picocom -b "$BAUD" --imap lfcrlf --logfile "$LOGDIR/session-$(date +%Y%m%d-%H%M%S).log" "$DEV"
elif command -v minicom >/dev/null 2>&1; then
    exec minicom -D "$DEV" -b "$BAUD" -8 -C "$LOGDIR/session-$(date +%Y%m%d-%H%M%S).log"
elif command -v screen >/dev/null 2>&1; then
    exec screen -L -Logfile "$LOGDIR/session-$(date +%Y%m%d-%H%M%S).log" "$DEV" "$BAUD"
else
    echo "error: install one of tio / picocom / minicom / screen" >&2
    exit 1
fi
