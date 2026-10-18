#!/bin/bash
# os/macos/maintenance.sh — [role] SETUP.md §3b "Disk maintenance". Weekly,
# Sunday 04:00 (assets/com.machine-setup.maintenance.plist), as the user.
# Reclaims what grows without anyone noticing on a build/test server:
#
#  - simulators whose runtime is gone (`simctl delete unavailable`)
#  - Xcode DerivedData folders untouched for 30+ days
#  - Homebrew download cache older than 30 days
#  - DANGLING podman images only — never containers, volumes or tagged
#    images (the home-automation stack will live there)
#
# One summary line per run → ~/Library/Logs/machine-setup-maintenance.log.
# A failed step writes FAILED=<step>; health-check.sh turns that into an
# alert, so a broken cleanup can't quietly let the disk fill.

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOMEBREW_NO_AUTO_UPDATE=1
LOG="$HOME/Library/Logs/machine-setup-maintenance.log"
mkdir -p "$(dirname "$LOG")"
failed=()
free_gb() { /bin/df -g /System/Volumes/Data | awk 'NR==2{print $4}'; }
before=$(free_gb)

if [ -x /usr/bin/xcrun ] && xcrun simctl help >/dev/null 2>&1; then
  xcrun simctl delete unavailable >/dev/null 2>&1 || failed+=(simctl)
fi

DD="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DD" ]; then
  find "$DD" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || failed+=(derived-data)
fi

command -v brew >/dev/null && { brew cleanup -s --prune=30 >/dev/null 2>&1 || failed+=(brew); }

if command -v podman >/dev/null && podman machine list --format '{{.Running}}' 2>/dev/null | grep -q true; then
  podman image prune -f >/dev/null 2>&1 || failed+=(podman)
fi

after=$(free_gb)
echo "$(date '+%F %T') free ${before}G → ${after}G (+$((after - before))G)${failed[*]:+  FAILED=${failed[*]}}" >> "$LOG"
