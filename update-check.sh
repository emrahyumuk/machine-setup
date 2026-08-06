#!/bin/bash
# Weekly pending-updates summary -> one desktop notification.
# Clicking the notification opens a terminal running `upcheck` (details +
# what-to-do notes). Covers the four channels of the Sunday ritual
# (SETUP.md "Update cadence"): dnf, flatpak, fwupd, npm -g.
# Installed to ~/.local/bin by bootstrap; triggered by update-check.timer.
# ponytail: counts are crude line counts — upcheck shows the details.
set -o pipefail

dnf_n=$(dnf -q check-update 2>/dev/null | grep -Ec '^[[:alnum:]]') || true
fp_n=$(flatpak remote-ls --updates --app 2>/dev/null | wc -l)
npm_n=$(npm outdated -g --parseable 2>/dev/null | wc -l)
if fwupdmgr get-updates >/dev/null 2>&1; then fw="yes"; else fw="no"; fi

total=$((dnf_n + fp_n + npm_n))
if [ "$total" -eq 0 ] && [ "$fw" = "no" ]; then
  body="Everything up to date. Reboot ritual still applies."
else
  body="dnf: $dnf_n · flatpak: $fp_n · npm -g: $npm_n · firmware: $fw"
fi

# -A makes notify-send wait and print the clicked action id; bounded so an
# ignored notification can't leave this process waiting past the week.
action=$(timeout 12h notify-send -A default="Open upcheck" \
  -i software-update-available "Sunday update ritual" "$body") || true

if [ "$action" = "default" ]; then
  # systemd-run: own transient scope — a plain `&` child dies with the
  # service cgroup the moment this script exits (verified the hard way)
  systemd-run --user --collect -- ghostty -e zsh -ic 'upcheck; exec zsh -i'
fi
