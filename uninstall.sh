#!/bin/sh
# uninstall.sh — remove the disk probe LaunchAgent. Leaves logs behind.
set -eu

LABEL="network.awai.fleet.diskprobe"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_NUM="$(id -u)"

launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
echo "removed: $LABEL"
