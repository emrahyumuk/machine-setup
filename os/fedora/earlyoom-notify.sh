#!/bin/bash
# Desktop notification when earlyoom kills a process.
# Why not earlyoom's own -n: systembus-notify is retired from Fedora repos
# (F44), and earlyoom runs with DynamicUser=true — no root, no sudo, no
# reaching the user session from inside. Tailing the journal FROM the user
# session avoids the sandbox entirely (works because the user is in wheel,
# which can read the system journal).
# "to process" filters out earlyoom's startup lines, which also say
# "sending SIGTERM when mem avail <= ..." and would false-fire on boot.
journalctl -fq -o cat -u earlyoom.service --since now \
  | grep --line-buffered -E 'sending SIG(TERM|KILL) to process' \
  | while IFS= read -r line; do
      notify-send -u critical -i dialog-warning "earlyoom" "$line"
    done
