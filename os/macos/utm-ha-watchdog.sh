#!/bin/bash
# os/macos/utm-ha-watchdog.sh — [role] SETUP.md §3b "UTM VM at login": keep
# the UTM VM "Home Assistant" running. Run by the LaunchAgent
# com.machine-setup.utm-vm at login and every 2 minutes after; installed as
# ~/.local/bin/utm-ha-watchdog by bootstrap.sh --server.
#
# When utm-vms says the VM is `stopped` (with UTM quit every VM is) or does
# not list it, `utmctl start` it, which launches UTM too. `started` and
# `unknown` (starting, saving, paused, utmctl not answering) are left to the
# next run. It touches only this VM — never the Windows VM (rigo's verify
# harness owns that one), never a stop or a quit.
# Quiet while the VM runs; each start is one line in
# ~/Library/Logs/machine-setup-utm-vm.log (the agent's StandardOutPath).
#
# A deliberate stop (`ha host shutdown`) is undone within 2 minutes: unload
# the agent first (mra-server docs/50 §10).

VM="Home Assistant"
export PATH="/Applications/UTM.app/Contents/MacOS:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

st=$("$HOME/.local/bin/utm-vms" | awk -F'\t' -v n="$VM" '$1 == n { print $2 }')
case "$st" in started|unknown) exit 0 ;; esac

# utmctl can hang on a missing Automation grant: same alarm as utm-vms
out=$(perl -e 'alarm 60; exec @ARGV' utmctl start "$VM" 2>&1)
rc=$?
if [ $rc -eq 0 ]; then res="started"; else res="FAILED (exit $rc): $out"; fi
printf '%s %s was %s → utmctl start: %s\n' "$(date '+%F %T')" "$VM" "${st:-not listed}" "$res"
exit $rc
