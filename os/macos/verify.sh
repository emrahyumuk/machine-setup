#!/bin/bash
# os/macos/verify.sh — drift check: runs every VERIFY line of SETUP.md (§1 +
# §2c macOS + §3b MacBook Pro) and prints PASS / FAIL / SKIP. Read-only.
# Exit 1 if anything FAILs.
#
# WHY: same reason as the Fedora one — the drifts that hurt are the silent
# ones. On macOS the candidates so far: (a) LaunchServices quietly handing
# .m3u8/.mp4 back to Music/QuickTime after an OS update, (b) `pmset` AC
# settings reset by a major macOS upgrade, (c) the update notifier reporting
# "0 pending" because its checks failed (2026-10-18). None of them make a sound.
#
# Usage: os/macos/verify.sh      (everything here is user-readable; no sudo
#                                 variant is needed — unlike Fedora)
#        machine-verify          (installed by bootstrap to ~/.local/bin)

pass=0; fail=0; skip=0
ok()   { printf '  \e[32mPASS\e[0m  %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \e[31mFAIL\e[0m  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; fail=$((fail+1)); }
skipc(){ printf '  \e[33mSKIP\e[0m  %s\n' "$1"; skip=$((skip+1)); }
sec()  { printf '\n\e[1m%s\e[0m\n' "$1"; }
H="$HOME"
BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$H/.local/bin:$H/.cargo/bin:$PATH"

sec "§1 Personal"
if command -v duti >/dev/null; then
  # The Fedora trap ".m3u8 falls to the music app" reproduces here verbatim:
  # LaunchServices hands it to Music.app unless a video player claims it.
  for ext in m3u8 mp4 mkv webm; do
    h=$(duti -x "$ext" 2>/dev/null | sed -n 3p)
    [ "$h" = "com.colliderli.iina" ] && ok ".$ext → IINA" \
      || bad ".$ext → ${h:-none} (expect com.colliderli.iina)" "duti -s com.colliderli.iina $ext all, then approve the macOS dialog"
  done
else skipc "file associations (duti not installed)"; fi
grep -q '^deinterlace=yes' "$H/.config/mpv/mpv.conf" 2>/dev/null && ok "mpv deinterlace=yes" || bad "mpv.conf deinterlace"
grep -q '^hwdec=videotoolbox-copy' "$H/.config/mpv/mpv.conf" 2>/dev/null && ok "mpv hwdec=videotoolbox-copy" || bad "mpv.conf hwdec (macOS: videotoolbox-copy, not vaapi-copy)"
[ "$(defaults read com.colliderli.iina useUserDefinedConfDir 2>/dev/null)" = 1 ] \
  && ok "IINA reads ~/.config/mpv" || bad "IINA not pointed at the mpv config dir" "defaults write com.colliderli.iina useUserDefinedConfDir -bool true"
grep -q '^show_notifications = false' "$H/.config/starship.toml" 2>/dev/null && ok "starship notifications off" || bad "starship show_notifications must be false (agent-PTY storm)"
[ -n "$(git config --global --get user.email 2>/dev/null)" ] && ok "git identity set" || bad "git user.email unset" "git config --global user.name/user.email"
[ "$(git config --global --get core.pager 2>/dev/null)" = delta ] && ok "git pager = delta" || bad "git core.pager (expect delta — dotfiles/gitconfig.template)"
grep -q 'fuse-ld=mold' "$H/.cargo/config.toml" 2>/dev/null \
  && bad "~/.cargo/config.toml sets mold — that is a Linux linker, it will break every build here" \
  || ok "no mold rustflags (correct on macOS — Apple's ld_prime is the linker)"
n=$(which -a claude 2>/dev/null | sort -u | wc -l | tr -d ' ')
[ "$n" = 1 ] && [ -x "$H/.local/bin/claude" ] && ok "claude: single native install" || bad "claude install" "which -a claude → $n entries"
# owner item: a machine without a synced ~/.claude is not a failure
if [ -d "$H/.claude/.git" ]; then
  [ "$(git -C "$H/.claude" remote get-url origin 2>/dev/null)" = "https://github.com/emrahyumuk/dot-claude-config" ] \
    && ok "~/.claude is the dot-claude-config checkout" || bad "~/.claude is a repo but not dot-claude-config"
else skipc "~/.claude not synced (owner item, SETUP.md §2c)"; fi
if [ -f "$H/.claude/settings.json" ]; then
  grep -q '"/home/' "$H/.claude/settings.json" \
    && bad "settings.json has absolute /home/ paths (hooks fire errors on the Mac)" "use the \$HOME + existence-check form — SETUP.md §1 Claude Code" \
    || ok "Claude settings.json is path-portable"
fi
if [ -x "$H/.claude/bin/link-project-memory" ]; then
  out=$("$H/.claude/bin/link-project-memory" --check 2>&1 | tail -1)
  case "$out" in "0 unlinked, 0 conflict(s)") ok "project memory slugs linked to the other machine's";;
    *) bad "link-project-memory --check: $out" "run link-project-memory after cloning projects";; esac
fi

sec "§2c macOS"
command -v brew >/dev/null && ok "Homebrew: $(brew --version | head -1)" || bad "Homebrew missing"
hn=$(scutil --get HostName 2>/dev/null)
if [ -z "$hn" ]; then bad "HostName unset" "sudo scutil --set HostName <name> (Chromium singleton-lock trap)"
else
  # All three must agree: LocalHostName is the Bonjour name (<name>.local) —
  # with only HostName set, ssh <name>.local does not resolve (2026-10-18).
  lhn=$(scutil --get LocalHostName 2>/dev/null); cn=$(scutil --get ComputerName 2>/dev/null)
  [ "$lhn" = "$hn" ] && [ "$cn" = "$hn" ] && ok "HostName = LocalHostName = ComputerName = $hn" \
    || bad "names disagree: HostName=$hn LocalHostName=$lhn ComputerName=$cn" "sudo scutil --set LocalHostName $hn && sudo scutil --set ComputerName $hn"
fi
for t in starship zoxide fzf atuin eza bat duf btop lazygit delta nvim podman mas gh tmux jq node pnpm codex opencode agy; do
  command -v "$t" >/dev/null && ok "$t" || bad "$t missing"
done
for p in zsh-autosuggestions zsh-syntax-highlighting; do
  [ -f "$BREW_PREFIX/share/$p/$p.zsh" ] && ok "$p sourced from $BREW_PREFIX" || bad "$p not at $BREW_PREFIX/share/$p/"
done
case "$(node --version 2>/dev/null)" in v24.*) ok "system node is 24 (brew node@24)";; *) bad "node is $(node --version 2>/dev/null || echo none), expect v24" "brew install node@24 && brew link --force node@24";; esac
npm config get allow-scripts 2>/dev/null | grep -q opencode-ai && ok "npm allow-scripts covers opencode-ai" || bad "npm allow-scripts unset (npm 11 blocks postinstalls)" "npm config set allow-scripts=opencode-ai,protobufjs,re2 --location=user"
# Non-interactive zsh reads only ~/.zshenv — what `ssh mra-mac <cmd>` and agent
# tool calls get. Fresh env so this shell's PATH can't mask a missing .zshenv.
miss=$(env -i HOME="$H" /bin/zsh -c 'for c in brew node claude agy cargo; do command -v $c >/dev/null || printf "%s " $c; done')
[ -z "$miss" ] && ok "non-interactive zsh sees brew/node/claude/agy/cargo (.zshenv)" || bad "non-interactive zsh misses: $miss" "cp dotfiles/macos/zshenv ~/.zshenv"
grep -q '^alias docker=podman' "$H/.zshrc" 2>/dev/null && ok "docker → podman alias" || bad "docker alias missing from ~/.zshrc"
grep -q 'pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null && ok "Touch ID for sudo" \
  || bad "Touch ID not enabled for sudo" "sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local && uncomment the pam_tid line"
launchctl list 2>/dev/null | grep -q 'com.machine-setup.update-check' \
  && ok "update-check agent loaded (Sun 18:00)" || bad "update-check LaunchAgent not loaded" "launchctl bootstrap gui/\$UID ~/Library/LaunchAgents/com.machine-setup.update-check.plist"
[ -L "$H/.local/bin/machine-verify" ] && ok "machine-verify is a symlink into the repo" || bad "machine-verify is a copy (goes stale)" "ln -sfn <repo>/os/macos/verify.sh ~/.local/bin/machine-verify"
grep -q 'check FAILED' "$H/.local/bin/update-check" 2>/dev/null \
  && ok "update-check reports failed channels (not a silent 0)" || bad "update-check is the old silent-0 version" "ln -sfn <repo>/os/macos/update-check.sh ~/.local/bin/update-check"
UL="$H/Library/Logs/machine-setup-update-check.log"
if [ -s "$UL" ]; then
  tail -1 "$UL" | grep -q 'FAILED=' && bad "last update check FAILED: $(tail -1 "$UL")" "run update-check by hand and read the log" || ok "last update check ran clean"
else skipc "update-check has not run yet"; fi
SU=/Library/Preferences/com.apple.SoftwareUpdate
[ "$(defaults read $SU CriticalUpdateInstall 2>/dev/null)" != 0 ] \
  && [ "$(defaults read $SU ConfigDataInstall 2>/dev/null)" != 0 ] \
  && ok "security responses + XProtect data still automatic" || bad "CriticalUpdateInstall/ConfigDataInstall off — security updates must stay automatic"
if command -v podman >/dev/null && ! grep -qx server "$H/.config/machine-setup/roles" 2>/dev/null; then
  # on the server this is a hard check in the [role] block below
  podman machine list --format '{{.Name}} {{.Running}}' 2>/dev/null | grep -q 'true' \
    && ok "podman machine running" || skipc "podman machine not running (podman machine start)"
  sock="${DOCKER_HOST#unix://}"
  [ -n "$sock" ] && [ -S "$sock" ] && ok "DOCKER_HOST socket present" || skipc "DOCKER_HOST socket absent (machine stopped?)"
fi
fdesetup status 2>/dev/null | grep -q 'FileVault is On' && ok "FileVault on" || bad "FileVault off"
KJ="$H/.config/karabiner/karabiner.json"
if [ -d /Applications/Karabiner-Elements.app ]; then
  n=$(jq '[.profiles[] | select(.selected) | .complex_modifications.rules[]? | select(.description | startswith("PC-style"))] | length' "$KJ" 2>/dev/null)
  [ "${n:-0}" = 4 ] && ok "Karabiner PC-style rules active (4)" || bad "Karabiner PC-style rules: ${n:-0}/4" "re-run the keyboard step of os/macos/bootstrap.sh"
else bad "Karabiner-Elements not installed" "brew install --cask karabiner-elements"; fi
grep -q 'terminal.sendSequence' "$H/Library/Application Support/Code/User/keybindings.json" 2>/dev/null \
  && ok "VS Code terminal gets raw Ctrl codes back" || bad "VS Code terminal keybindings missing" "cp dotfiles/macos/vscode-keybindings.json → VS Code User/keybindings.json"

sec "§3b Hardware — MacBook Pro 14\" (M2 Pro)"
# autorestart (restart after a power failure) is an Intel-era SMC knob: Apple
# Silicon does not expose it — `pmset -g cap` has no such capability and
# setting it errors out. The battery rides through short outages anyway.
pmset -g cap 2>/dev/null | grep -q autorestart \
  || skipc "autorestart not a knob on Apple Silicon (battery rides through outages)"
# macOS exposes no supported read-back for the 80% charge limit; it lives in
# Settings → Battery → Charging. Checked by eye, not by script.
skipc "battery 80% charge limit (no CLI read-back — verify in Settings → Battery)"
printf '        battery now: %s\n' "$(pmset -g batt 2>/dev/null | sed -n 2p)"
mb=$(defaults read com.apple.AppleMultitouchMouse MouseButtonMode 2>/dev/null)
if system_profiler SPBluetoothDataType 2>/dev/null | grep -q 'Magic Mouse'; then
  [ "$mb" = TwoButton ] && ok "Magic Mouse secondary click on" || bad "Magic Mouse MouseButtonMode=${mb:-unset}" "Settings → Mouse → Secondary Click → Click Right Side"
else skipc "no Magic Mouse paired"; fi
d=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c 'Resolution')
[ "${d:-0}" -ge 2 ] && ok "external display attached ($d displays)" || skipc "only the built-in display detected"

# [role] items: only where bootstrap --server marked the machine (SETUP.md §3b).
# A plain Mac must never FAIL a server check.
if grep -qx server "$H/.config/machine-setup/roles" 2>/dev/null; then
sec "§3b [role] always-on home server"
ac=$(pmset -g custom 2>/dev/null | sed -n '/^AC Power:/,$p')
grep -qE '^ +sleep +0' <<<"$ac" && ok "AC: never sleeps" || bad "AC sleep != 0" "sudo pmset -c sleep 0"
grep -qE '^ +womp +1' <<<"$ac" && ok "AC: wake for network" || bad "AC womp != 1" "sudo pmset -c womp 1"
[ "$(defaults read $SU AutomaticallyInstallMacOSUpdates 2>/dev/null)" = 0 ] \
  && ok "macOS auto-install off (upall owns updates)" || bad "macOS updates auto-install (unannounced server restarts)" "sudo defaults write $SU AutomaticallyInstallMacOSUpdates -bool false"
nc -z -G1 127.0.0.1 22 2>/dev/null && ok "Remote Login (SSH) listening" || bad "SSH not listening" "Settings → General → Sharing → Remote Login"
nc -z -G1 127.0.0.1 5900 2>/dev/null && ok "Screen Sharing listening" || bad "Screen Sharing off" "Settings → General → Sharing → Screen Sharing"
KO=/etc/ssh/sshd_config.d/010-machine-setup.conf
if [ ! -s "$H/.ssh/authorized_keys" ]; then
  skipc "SSH key-only login pending — no ~/.ssh/authorized_keys yet (add a key, test it, then $KO)"
elif grep -qE '^PasswordAuthentication +no' "$KO" 2>/dev/null && grep -qE '^KbdInteractiveAuthentication +no' "$KO" 2>/dev/null; then
  # both: with UsePAM yes (macOS 100-macos.conf) keyboard-interactive is a password path too
  ok "SSH key-only (password + keyboard-interactive off)"
else
  bad "authorized_keys present but SSH still accepts passwords" "write $KO — SETUP.md §3b"
fi
if command -v tailscale >/dev/null; then
  tailscale status >/dev/null 2>&1 && ok "tailscale up ($(tailscale ip -4 2>/dev/null | head -1))" || bad "tailscale not connected" "sudo brew services start tailscale && tailscale up"
else bad "tailscale missing" "brew install tailscale (the formula — daemon runs before login)"; fi
# loaded is not enough: the first agent "started successfully" and left no VM
launchctl list 2>/dev/null | grep -q 'com.machine-setup.podman-machine' \
  && ok "podman machine starts at login (LaunchAgent)" || bad "podman autostart agent not loaded" "bootstrap.sh --server, or launchctl bootstrap gui/\$UID ~/Library/LaunchAgents/com.machine-setup.podman-machine.plist"
podman machine list --format '{{.Running}}' 2>/dev/null | grep -q true \
  && ok "podman machine running" || bad "podman machine not running on the server" "podman machine start; check ~/Library/Logs/machine-setup-podman-machine.log"
for j in health-check maintenance; do
  [ -f /Library/LaunchDaemons/com.machine-setup.$j.plist ] && ok "$j LaunchDaemon installed" \
    || bad "$j LaunchDaemon missing" "bootstrap.sh --server (sudo section) — SETUP.md §3b Health"
done
[ -s "$H/.config/machine-setup/healthcheck-url" ] && ok "heartbeat URL configured" \
  || bad "no heartbeat URL — nobody hears it if this Mac goes down" "healthchecks.io ping URL → ~/.config/machine-setup/healthcheck-url"
HL="$H/Library/Logs/machine-setup-health.log"
if [ -s "$HL" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$HL") ))
  last=$(tail -1 "$HL")
  if [ "$age" -gt 900 ]; then bad "health log not written for $((age / 60)) min (job not running?)"
  else
    case "$last" in *ping=ok*|*ping=fail-sent*) ok "health check pinging (${last##*ping=})";;
      *) bad "health check: ${last##*ping=}" "see $HL";; esac
  fi
else bad "health check has never run"; fi
case "$(xcode-select -p 2>/dev/null)" in
  /Applications/Xcode*.app/*) ok "xcode-select → full Xcode"
    xcrun simctl list runtimes 2>/dev/null | grep -q '^iOS' && ok "iOS simulator runtime installed" || bad "no iOS simulator runtime" "xcodebuild -downloadPlatform iOS";;
  *) bad "xcode-select points at CommandLineTools, not Xcode" "sudo xcode-select -s /Applications/Xcode.app";;
esac
for t in aarch64-apple-ios aarch64-apple-ios-sim; do
  rustup target list --installed 2>/dev/null | grep -qx "$t" && ok "rust target $t" || bad "rust target $t missing" "rustup target add $t"
done
else
  skipc "[role] server checks — machine not marked (~/.config/machine-setup/roles)"
fi

printf '\n\e[1m%d PASS  %d FAIL  %d SKIP\e[0m\n' "$pass" "$fail" "$skip"
[ "$fail" = 0 ]
