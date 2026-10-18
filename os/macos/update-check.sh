#!/bin/bash
# os/macos/update-check.sh — one desktop notification summarising what is
# pending across the four macOS update channels. Fired by
# assets/com.machine-setup.update-check.plist (Sun 18:00), doubling as the
# weekly-ritual reminder. Mirrors os/fedora/update-check.sh; the channels
# differ (see SETUP.md §2c "Update cadence").
#
# Channels: brew (formulae + casks) · softwareupdate (macOS + firmware, which
# on a Mac ride the same update) · npm -g (agent CLIs) · mas (App Store).
#
# TRAP (found 2026-10-18): the first version silenced every error and counted
# lines with `grep -c`, so a failed check printed "0" — five Sundays in a row
# said "Everything up to date" while 59 updates (incl. a macOS security
# release) were pending. A failed channel must SAY it failed, never read as 0.

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# launchd may fire right after a wake, before Wi-Fi is back: wait up to 5 min.
for _ in $(seq 1 10); do
  curl -sfI --max-time 5 https://formulae.brew.sh >/dev/null && break
  sleep 30
done

failed=()
count() { grep -c . || true; }

if brew update >/dev/null && out=$(brew outdated --greedy); then
  n_brew=$(count <<<"$out")
else failed+=(brew); n_brew=0; fi

if out=$(softwareupdate -l 2>&1) && ! grep -qiE 'error|could not|cannot' <<<"$out"; then
  n_os=$(grep -cE '^\s*\* ' <<<"$out" || true)
else failed+=(macOS); n_os=0; fi

n_npm=0
if command -v npm >/dev/null; then
  # npm outdated exits 1 when something IS outdated — judge by stderr instead
  out=$(npm outdated -g --parseable 2>"${TMPDIR:-/tmp}/uc-npm.err")
  [ -s "${TMPDIR:-/tmp}/uc-npm.err" ] && failed+=(npm) || n_npm=$(count <<<"$out")
fi

n_mas=0
if command -v mas >/dev/null; then
  if out=$(mas outdated); then n_mas=$(count <<<"$out"); else failed+=(mas); fi
fi

total=$((n_brew + n_os + n_npm + n_mas))
if [ ${#failed[@]} -gt 0 ]; then
  subtitle="check FAILED: ${failed[*]}"
  body="brew $n_brew · macOS $n_os · npm -g $n_npm · App Store $n_mas — see ~/Library/Logs/machine-setup-update-check.log"
elif [ "$total" -eq 0 ]; then
  subtitle="0 pending"; body="Everything up to date."
else
  subtitle="$total pending"; body="brew $n_brew · macOS $n_os · npm -g $n_npm · App Store $n_mas — run upall"
fi

/usr/bin/osascript -e "display notification \"$body\" with title \"Weekly update check\" subtitle \"$subtitle\""
echo "$(date '+%F %T')  brew=$n_brew os=$n_os npm=$n_npm mas=$n_mas${failed[*]:+  FAILED=${failed[*]}}"
