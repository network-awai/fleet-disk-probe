# fleet-disk-probe

One LaunchAgent, one script, one POST. Reports free space on `/System/Volumes/Data`
to a collector on the LAN every 30 minutes so the fleet can enforce
"keep at least 10% free" without anyone shelling into a machine.

## Why a local agent instead of remote SSH

Orca pairs the minis as **environments** (`orca environment list`), but the Orca CLI
has no "run a command on that environment" verb: the mediated path is an agent
worker (`orca orchestration worker-start --on <environment>`), which costs a model
turn each time. A 30-minute disk check should not cost a model turn. So the check
runs **locally** on each machine and pushes a 4-field JSON body over the LAN.

Installation still goes through Orca (once), never through hand-copied SSH keys.

## Install (on each machine)

```sh
git clone https://github.com/network-awai/fleet-disk-probe.git ~/fleet-disk-probe
~/fleet-disk-probe/install.sh http://10.10.10.1:8787
```

`install.sh` writes `~/Library/LaunchAgents/network.awai.fleet.diskprobe.plist`
with `StartInterval` 1800 and `RunAtLoad`, loads it, and runs it once.

Remove with `~/fleet-disk-probe/uninstall.sh`.

## Manual run

```sh
./disk_probe.sh http://10.10.10.1:8787
# probe: host=joseph free=40663708KiB total=239362496KiB (16.99%) post=200
```

## What it sends

```json
{"host": "joseph", "free_kib": 40663708, "total_kib": 239362496, "min_kib": 40663708}
```

`free_kib` is the **minimum of three readings two seconds apart**. A single `df`
can catch the disk mid-write and report space that is about to vanish; the gate
decisions use the minimum.

Exit code is non-zero when the POST does not return 200, so the LaunchAgent log
shows the failure instead of silently succeeding.

## Collector contract

`POST /disk` with the JSON above, `200` on acceptance, `400` with a reason when a
field is missing. `GET /health` returns `healthy`. The collector appends one TSV
row per report and computes the percentage itself, so a broken client cannot claim
"OK" for a full disk.
