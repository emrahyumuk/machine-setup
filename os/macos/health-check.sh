#!/bin/bash
# os/macos/health-check.sh — [role] SETUP.md §3b "Health: heartbeat + memory
# + disk". Runs every 5 min (assets/com.machine-setup.health-check.plist, a
# LaunchDaemon running as the user, so it works with nobody logged in at the
# desk). Three jobs:
#
#  1. Heartbeat: ping a dead-man's-switch receiver — an Uptime Kuma Push
#     monitor or a healthchecks.io check (SETUP.md §3b names this Mac's).
#     When the pings STOP (machine off, frozen, offline, stuck at the
#     FileVault screen) the receiver alerts the phone — the one failure a
#     machine can't report about itself.
#  2. Trend log: one line per run (memory pressure, free %, swap, disk free,
#     Wi-Fi channel/signal, top memory users) → ~/Library/Logs/machine-setup-health.log.
#  3. Alerts: memory pressure at warn+ for 3 runs in a row (15 min), disk free
#     under the floor, a failed weekly maintenance, or a GitHub Actions runner
#     that is installed but not running (§3b "GitHub Actions runner") → the
#     ping reports DOWN
#     (Kuma status=down, healthchecks.io URL/fail) with the reason as its
#     message, so the alert says WHY.
#
# The push/ping URL is a secret-ish token: it lives in
# ~/.config/machine-setup/healthcheck-url (chmod 600), never in the repo, and
# reaches curl on stdin (-K -), never in argv: other users on this Mac (the
# GitHub runner's) can read every process's arguments with ps.
# No URL yet → still logs, and says so in the log (verify FAILs on it).
#
# Rule carried over from update-check (2026-10-18): a failed probe must never
# look like a clean result — a curl failure is logged as such.

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
CFG="$HOME/.config/machine-setup"
LOG="$HOME/Library/Logs/machine-setup-health.log"
STATE="$CFG/health.state"
RSTATE="$CFG/runner.state"
MLOG="$HOME/Library/Logs/machine-setup-maintenance.log"
DISK_FLOOR_GB=${DISK_FLOOR_GB:-30}   # env override = a way to test the alert path
RUNNER_PLIST=/Library/LaunchDaemons/com.machine-setup.github-runner.plist
mkdir -p "$CFG" "$(dirname "$LOG")"

# keep the trend log bounded (~5 MB ≈ 4 months of 5-minute lines)
[ -f "$LOG" ] && [ "$(stat -f %z "$LOG")" -gt 5000000 ] && mv "$LOG" "$LOG.1"

# kern.memorystatus_vm_pressure_level: 1 normal, 2 warn, 4 critical
lvl=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo 0)
free=$(memory_pressure -Q 2>/dev/null | awk '/percentage/{print $NF}')
swap=$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $6}')
disk=$(/bin/df -g /System/Volumes/Data 2>/dev/null | awk 'NR==2{print $4}')
wifi=$(system_profiler SPAirPortDataType 2>/dev/null \
  | sed -n '/Current Network Information:/,/Other Local Wi-Fi Networks:/p' \
  | awk -F': ' '/Channel:/{c=$2} /Signal \/ Noise:/{s=$2} END{printf "%s|%s", c, s}' | head -c 60)
top=$(ps -Ao rss=,comm= | sort -rn | head -3 | awk '{n=$2; sub(".*/","",n); printf "%s:%dM ", n, $1/1024}')

# consecutive runs at warn+ (state survives between runs)
hi=$(cat "$STATE" 2>/dev/null || echo 0)
if [ "${lvl:-0}" -ge 2 ]; then hi=$((hi + 1)); else hi=0; fi
echo "$hi" > "$STATE"

problems=()
[ "$hi" -ge 3 ] && problems+=("memory pressure level $lvl for $((hi * 5))+ min (free $free, swap $swap; top: $top)")
[ -n "$disk" ] && [ "$disk" -lt "$DISK_FLOOR_GB" ] && problems+=("disk free ${disk} GB < ${DISK_FLOOR_GB} GB")
[ -f "$MLOG" ] && tail -1 "$MLOG" | grep -q 'FAILED' && problems+=("last weekly maintenance FAILED: $(tail -1 "$MLOG" | cut -c1-120)")
# Runner: "installed" is its daemon plist (this user cannot see inside the
# runner user's home); pgrep sees every user's processes, so it is held to the
# plist's user and the listener's path (an editor on a file named like it must
# not count). Two misses in a row: a self-update restarts the listener, and
# one sample can land in that gap.
if [ -f "$RUNNER_PLIST" ] && ! pgrep -q -u "$(/usr/libexec/PlistBuddy -c 'Print :UserName' "$RUNNER_PLIST")" \
     -f '/actions-runner/bin/Runner\.Listener'; then
  rmiss=$(( $(cat "$RSTATE" 2>/dev/null || echo 0) + 1 ))
else rmiss=0; fi
echo "$rmiss" > "$RSTATE"
[ "$rmiss" -ge 2 ] && problems+=("github runner not running")

line="mem=$lvl free=${free:-?} swap=${swap:-?} disk=${disk:-?}G wifi=${wifi:-?} top=[$top]"
URL=$(cat "$CFG/healthcheck-url" 2>/dev/null | tr -d '[:space:]')
# Two receivers, picked by the URL's shape:
#  - Uptime Kuma Push monitor (…/api/push/<token>…): GET with status=up|down&msg=
#  - healthchecks.io (or anything with its API): POST body to URL or URL/fail
if [ -z "$URL" ]; then
  ping="NO-URL"
elif [[ "$URL" == */api/push/* ]]; then
  base="${URL%%\?*}"
  if [ ${#problems[@]} -gt 0 ]; then st=down; msg="${problems[*]}"; else st=up; msg="OK mem=$lvl disk=${disk}G"; fi
  if printf 'url = "%s"\n' "$base" | curl -fsS -m 10 --retry 3 -K - -G --data-urlencode "status=$st" --data-urlencode "msg=${msg:0:250}" --data-urlencode "ping=" >/dev/null 2>&1; then
    [ $st = up ] && ping="ok" || ping="fail-sent"
  else ping="PING-FAILED"; fi
elif [ ${#problems[@]} -gt 0 ]; then
  body=$(printf '%s\n' "${problems[@]}")
  printf 'url = "%s/fail"\n' "$URL" | curl -fsS -m 10 --retry 3 -K - --data-raw "$body" >/dev/null 2>&1 && ping="fail-sent" || ping="PING-FAILED"
else
  printf 'url = "%s"\n' "$URL" | curl -fsS -m 10 --retry 3 -K - --data-raw "$line" >/dev/null 2>&1 && ping="ok" || ping="PING-FAILED"
fi

echo "$(date '+%F %T') $line ping=$ping${problems[*]:+ PROBLEM: ${problems[*]}}" >> "$LOG"
