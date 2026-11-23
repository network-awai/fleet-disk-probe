#!/bin/sh
# fleet disk probe — measure /System/Volumes/Data and POST the result.
#
# Usage: disk_probe.sh [receiver-url]
#   receiver-url defaults to $FLEET_DISK_RECEIVER or http://10.10.10.1:8787
#
# Measures three times (2s apart) because a single df can land mid-write and
# report free space that is about to disappear. Reports the minimum, which is
# the number the build gate uses.
set -u

RECEIVER="${1:-${FLEET_DISK_RECEIVER:-http://10.10.10.1:8787}}"
TARGET="/System/Volumes/Data"
HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"

read_total_free() {
  df -k "$TARGET" | awk 'NR==2 {print $2, $4}'
}

min_free=""
total=""
i=1
while [ "$i" -le 3 ]; do
  set -- $(read_total_free)
  t="$1"; f="$2"
  total="$t"
  if [ -z "$min_free" ] || [ "$f" -lt "$min_free" ]; then min_free="$f"; fi
  i=$((i + 1))
  [ "$i" -le 3 ] && sleep 2
done

[ -n "$total" ] || { echo "probe: df failed" >&2; exit 1; }

code="$(curl -s -o /dev/null -w '%{http_code}' -m 10 \
  -X POST "$RECEIVER/disk" -H 'Content-Type: application/json' \
  -d "{\"host\":\"$HOST\",\"free_kib\":$min_free,\"total_kib\":$total,\"min_kib\":$min_free}" 2>/dev/null)"

pct="$(awk -v f="$min_free" -v t="$total" 'BEGIN{printf "%.2f", 100*f/t}')"
echo "probe: host=$HOST free=${min_free}KiB total=${total}KiB (${pct}%) post=$code"
[ "$code" = "200" ] || exit 1
