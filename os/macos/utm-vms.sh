#!/bin/bash
# os/macos/utm-vms.sh — [role] SETUP.md §3b "UTM VM state": print one
# tab-separated line per UTM VM: name, started|stopped|unknown, and the start
# time of a started VM (epoch seconds; empty if its process is not found).
# Installed as ~/.local/bin/utm-vms by bootstrap.sh. Reads only: it never
# starts or stops anything. Other jobs (a status reporter, a watchdog) call it
# instead of each talking to UTM their own way.
#
# Rules it keeps (measured, SETUP.md §3b "UTM VM at login"):
#  - The VM names come from `utmctl list` and are kept in
#    ~/.cache/utm-vms/names, so they are known with UTM quit. UTM's
#    Documents folder (the *.utm bundles) is only the first-run fallback:
#    from a LaunchAgent, macOS refuses to list another app's container
#    ("Operation not permitted", measured 2026-10-23).
#  - Telling UTM anything launches it, so with no UTM process every VM is
#    `stopped` and utmctl is never called. No names known then → nothing
#    printed, exit 1.
#  - utmctl can hang on a missing Automation grant: it runs under a 15 s
#    alarm. A timeout or a failure prints every VM `unknown` and exits 1.
#  - The start time is the QEMU process's absolute start (ps lstart), matched
#    by the bundle path in its arguments: stable across runs, unlike
#    now − etime.

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
DOCS="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents"
CACHE="$HOME/.cache/utm-vms/names"

names=()
if [ -s "$CACHE" ]; then
  while IFS= read -r n; do [ -n "$n" ] && names+=("$n"); done < "$CACHE"
else
  for b in "$DOCS"/*.utm; do
    [ -d "$b" ] && names+=("$(basename "$b" .utm)")
  done
fi

if ! pgrep -xq UTM; then
  [ ${#names[@]} -gt 0 ] || exit 1
  for n in "${names[@]}"; do printf '%s\tstopped\t\n' "$n"; done
  exit 0
fi

# `utmctl list`: a header, then "UUID  Status  Name" (the name may hold spaces)
if ! list=$(perl -e 'alarm 15; exec @ARGV' utmctl list 2>/dev/null); then
  for n in "${names[@]}"; do printf '%s\tunknown\t\n' "$n"; done
  exit 1
fi
names=()
while IFS= read -r n; do [ -n "$n" ] && names+=("$n"); done \
  < <(awk 'NR > 1 { $1 = ""; $2 = ""; sub(/^ +/, ""); print }' <<<"$list")
# an empty list (UTM still starting) must not replace the known names
[ ${#names[@]} -gt 0 ] && mkdir -p "$(dirname "$CACHE")" && printf '%s\n' "${names[@]}" > "$CACHE"

procs=$(LC_ALL=C ps -axo lstart=,args= | grep '[Q]EMULauncher')

for n in "${names[@]}"; do
  st=$(awk -v n="$n" 'NR > 1 { s = $2; $1 = ""; $2 = ""; sub(/^ +/, ""); if ($0 == n) print s }' <<<"$list")
  case "$st" in
    started)
      at=""
      # lstart is the first five fields: "Thu Oct 22 14:28:19 2026"
      ls=$(grep -F "/$n.utm/" <<<"$procs" | head -1 | awk '{ print $1, $2, $3, $4, $5 }')
      [ -n "$ls" ] && at=$(LC_ALL=C date -j -f '%a %b %d %T %Y' "$ls" +%s 2>/dev/null)
      printf '%s\tstarted\t%s\n' "$n" "$at" ;;
    stopped) printf '%s\tstopped\t\n' "$n" ;;
    *) printf '%s\tunknown\t\n' "$n" ;;          # starting, stopping, paused…
  esac
done
exit 0
