#!/bin/sh
# install.sh — install the disk probe as a per-user LaunchAgent (every 30 min).
#
# Usage: ./install.sh [receiver-url]
#   receiver-url defaults to http://10.10.10.1:8787 (jacob on the 10.10.10.0/24 LAN)
#
# Idempotent: re-running replaces the agent. Undo with ./uninstall.sh.
set -eu

RECEIVER="${1:-http://10.10.10.1:8787}"
HERE="$(cd "$(dirname "$0")" && pwd)"
LABEL="network.awai.fleet.diskprobe"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/fleet"
UID_NUM="$(id -u)"

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
chmod +x "$HERE/disk_probe.sh"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$HERE/disk_probe.sh</string>
    <string>$RECEIVER</string>
  </array>
  <key>StartInterval</key><integer>1800</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG_DIR/diskprobe.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/diskprobe.err</string>
  <key>ProcessType</key><string>Background</string>
  <key>LowPriorityIO</key><true/>
</dict>
</plist>
PLISTEOF

plutil -lint "$PLIST" >/dev/null

# Reload if already loaded; ignore "not loaded" on first install.
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
launchctl kickstart -k "gui/$UID_NUM/$LABEL"

sleep 1
if launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
  echo "installed: $LABEL -> $RECEIVER (every 1800s)"
else
  echo "installed the plist but the agent is not loaded" >&2
  exit 1
fi

echo "first run output:"
tail -n 3 "$LOG_DIR/diskprobe.log" 2>/dev/null || true
