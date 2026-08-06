#!/bin/bash
# Weekly pending-updates summary -> one desktop notification.
# Covers the four channels of the Sunday ritual (SETUP.md "Update cadence"):
# dnf, flatpak, fwupd, npm -g. Installed to ~/.local/bin by bootstrap;
# triggered by update-check.timer (Sun 18:00, catches up after suspend).
# ponytail: counts are crude line counts, not exact package lists — the
# ritual itself shows the details; this only answers "is there anything".
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

notify-send -i software-update-available \
  "Sunday update ritual" "$body"
