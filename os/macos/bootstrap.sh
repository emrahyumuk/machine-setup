#!/bin/bash
# Mechanical base only — the deterministic, judgment-free part of SETUP.md
# §1 + §2c for macOS (Apple Silicon). Everything requiring judgment (role
# items in §3b, look-and-feel, accounts, PWAs) lives in SETUP.md and is
# applied by reading it, not by this script.
# Idempotent: safe to re-run. Overwrites the dotfiles it installs (same rule
# as os/fedora/bootstrap.sh) — if ~/.zshrc etc. carry local edits, apply
# per-item instead.
#
# Run it in a REAL terminal (Ghostty/Terminal), not an agent shell: the last
# section needs sudo, and sudo cannot prompt (Touch ID or password) without
# a TTY.
#
# Written 2026-10-18 from what was actually applied on mbp14 (the 2026-09-06
# session's own bootstrap never reached the repo). Not yet run end-to-end on a
# fresh Mac — the first fresh run should be watched, and this note removed.
#
# --server: also apply the [role] items of SETUP.md §3b (always-on home
# server: no sleep on AC, wake for network, macOS auto-install off,
# Tailscale as a system daemon) and mark the machine with
# ~/.config/machine-setup/roles so verify checks them. Owner's choice for
# one machine — never the default.
set -euo pipefail
SERVER=0
[ "${1:-}" = --server ] && SERVER=1
# Mark the role FIRST: if the sudo section is declined or fails, verify must
# still check (and FAIL) the server items instead of silently skipping them.
if [ $SERVER = 1 ]; then mkdir -p ~/.config/machine-setup && echo server > ~/.config/machine-setup/roles; fi
cd "$(dirname "$0")/../.."   # repo root
OSD=os/macos

echo "== Homebrew =="
if ! command -v brew >/dev/null && [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

echo "== formulae (CLI stack — APPS.md 'CLI stack'; curated intent lives there) =="
brew install \
  starship zoxide fzf atuin eza bat duf btop lazygit git-delta neovim \
  zsh-autosuggestions zsh-syntax-highlighting \
  podman podman-compose mpv duti mas dockutil \
  node@24 pnpm gh tmux jq
[ $SERVER = 1 ] && brew install tailscale
brew link --force node@24 >/dev/null 2>&1 || true   # system node = 24 (Active LTS)

echo "== casks (desktop apps — APPS.md 'Desktop applications') =="
brew install --cask \
  ghostty font-jetbrains-mono-nerd-font visual-studio-code \
  firefox google-chrome thunderbird bitwarden iina whatsapp \
  spotify discord beekeeper-studio podman-desktop unity-hub gcloud-cli

echo "== dotfiles =="
mkdir -p ~/.config/ghostty ~/.config/mpv
cp dotfiles/macos/zshrc    ~/.zshrc
cp dotfiles/macos/zprofile ~/.zprofile
cp dotfiles/macos/zshenv   ~/.zshenv     # PATH for non-interactive shells (ssh <cmd>)
cp dotfiles/ghostty.config ~/.config/ghostty/config
cp dotfiles/starship.toml  ~/.config/starship.toml
cp dotfiles/macos/mpv.conf ~/.config/mpv/mpv.conf   # videotoolbox-copy, not vaapi-copy
# identity is never in the repo — template only when no gitconfig exists yet
[ -f ~/.gitconfig ] || cp dotfiles/gitconfig.template ~/.gitconfig

echo "== keyboard: Linux shortcuts outside terminals (SETUP.md §2c Keyboard) =="
# The Karabiner cask is a pkg (sudo) — installed in the sudo section below;
# its rules + VS Code's terminal keybindings are plain user files.
K=~/.config/karabiner
mkdir -p "$K/assets/complex_modifications"
cp dotfiles/macos/karabiner-pc-style.json "$K/assets/complex_modifications/machine-setup-pc-style.json"
if [ -f "$K/karabiner.json" ]; then
  jq --slurpfile a dotfiles/macos/karabiner-pc-style.json \
    '(.profiles[] | select(.selected) | .complex_modifications.rules) =
       ([(.profiles[] | select(.selected) | .complex_modifications.rules // [])[]
         | select(.description | startswith("PC-style") | not)] + $a[0].rules)' \
    "$K/karabiner.json" > "$K/karabiner.json.new" && mv "$K/karabiner.json.new" "$K/karabiner.json"
else
  jq -n --slurpfile a dotfiles/macos/karabiner-pc-style.json \
    '{profiles: [{name: "Default profile", selected: true,
       virtual_hid_keyboard: {keyboard_type_v2: "ansi"},
       complex_modifications: {rules: $a[0].rules}}]}' > "$K/karabiner.json"
fi
VSC="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSC"
[ -f "$VSC/keybindings.json" ] || cp dotfiles/macos/vscode-keybindings.json "$VSC/keybindings.json"

echo "== IINA = the mpv front-end, owns video/stream types =="
defaults write com.colliderli.iina useUserDefinedConfDir -bool true
for ext in m3u8 mp4 mkv webm; do duti -s com.colliderli.iina "$ext" all || true; done

echo "== nvm (per-project Node; never shadows the brew node) =="
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
  v=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["tag_name"])')
  # PROFILE=/dev/null: ~/.zshrc already sources nvm
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$v/install.sh" | PROFILE=/dev/null bash
fi
( export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"; nvm alias default system >/dev/null )

echo "== agent CLIs =="
# npm 11 blocks postinstall scripts unless allowed (SETUP.md §2 TRAP)
npm config set allow-scripts=opencode-ai,protobufjs,re2 --location=user
npm i -g @openai/codex opencode-ai
[ -x ~/.local/bin/claude ] || curl -fsSL https://claude.ai/install.sh | bash
if [ ! -x ~/.local/bin/agy ]; then
  # agy's installer appends a redundant PATH line to .zshrc AND .zprofile —
  # ~/.local/bin is already on PATH (zshenv/zshrc); restore both files after.
  cp ~/.zshrc /tmp/zshrc.$$; cp ~/.zprofile /tmp/zprofile.$$
  curl -fsSL https://antigravity.google/cli/install.sh | bash
  mv /tmp/zshrc.$$ ~/.zshrc; mv /tmp/zprofile.$$ ~/.zprofile
fi

echo "== Rust (rustup; NO mold — macOS links with Apple's ld_prime) =="
command -v rustup >/dev/null || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
[ $SERVER = 1 ] && "$HOME/.cargo/bin/rustup" target add aarch64-apple-ios aarch64-apple-ios-sim   # [role] iOS testing

echo "== podman machine =="
podman machine inspect >/dev/null 2>&1 || podman machine init
podman machine start 2>/dev/null || true

# (re)load a LaunchAgent; bootout may complete asynchronously, so retry once
load_agent() {
  launchctl bootout "gui/$(id -u)" "$1" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$1" 2>/dev/null || { sleep 2; launchctl bootstrap "gui/$(id -u)" "$1"; }
}

echo "== update notifier + drift check =="
mkdir -p ~/.local/bin ~/Library/LaunchAgents ~/Library/Logs
# symlinks, not copies: a copied verify went stale within weeks on Fedora
# (2026-10-11), and the Mac's copies needed re-installing three times in the
# 2026-10-18 session alone
ln -sfn "$PWD/$OSD/update-check.sh" ~/.local/bin/update-check
ln -sfn "$PWD/$OSD/verify.sh"       ~/.local/bin/machine-verify
P=~/Library/LaunchAgents/com.machine-setup.update-check.plist
sed "s#__HOME__#$HOME#g" $OSD/assets/com.machine-setup.update-check.plist > "$P"
load_agent "$P"

if [ $SERVER = 1 ]; then   # [role] podman VM + the UTM VM back after every reboot — no sudo needed
  brew install --cask utm
  # VM state for the jobs that report or watch the VMs (SETUP.md §3b "UTM VM state")
  ln -sfn "$PWD/$OSD/utm-vms.sh" ~/.local/bin/utm-vms
  # run by the utm-vm agent: starts the HA VM at login and whenever it stops
  ln -sfn "$PWD/$OSD/utm-ha-watchdog.sh" ~/.local/bin/utm-ha-watchdog
  # ⌘Q no longer quits UTM (it saves and quits every VM without asking): ⌃⌥⇧⌘Q does;
  # read at UTM's next launch (SETUP.md §3b "UTM VM at login")
  # shellcheck disable=SC2016  # '$' is the Shift modifier, not a variable
  defaults write com.utmapp.UTM NSUserKeyEquivalents -dict-add "Quit UTM" '@~^$q'
  for a in podman-machine utm-vm; do
    PM=~/Library/LaunchAgents/com.machine-setup.$a.plist
    sed "s#__HOME__#$HOME#g" $OSD/assets/com.machine-setup.$a.plist > "$PM"
    load_agent "$PM"
  done
fi

echo
echo "== sudo section (system-level; each line is SETUP.md §2c/§3b) =="
read -r -p "Apply the system-level settings now? [y/N] " a
if [[ "$a" =~ ^[Yy]$ ]]; then
  # Karabiner ships as a pkg → needs sudo; approve its driver + Input Monitoring after
  brew install --cask karabiner-elements
  # Touch ID for sudo — sudo_local survives OS updates (/etc/pam.d/sudo does not)
  if ! grep -q '^auth.*pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null; then
    sed 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local >/dev/null
  fi
  if [ $SERVER = 1 ]; then   # SETUP.md §3b [role] items
    # always-on: never sleep on AC, wake for network (display still sleeps)
    sudo pmset -c sleep 0 womp 1
    # upall owns macOS updates; security responses stay automatic
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
    # Tailscale as a LaunchDaemon: up before anyone logs in (the app variant is not)
    sudo brew services start tailscale
    # health heartbeat + weekly disk maintenance: LaunchDaemons running as the
    # user, so they work with nobody logged in at the desk (§3b "Health")
    for j in health-check maintenance; do
      ln -sfn "$PWD/$OSD/$j.sh" ~/.local/bin/$j
      D=/Library/LaunchDaemons/com.machine-setup.$j.plist
      sed -e "s#__HOME__#$HOME#g" -e "s#__USER__#$(id -un)#g" $OSD/assets/com.machine-setup.$j.plist | sudo tee "$D" >/dev/null
      sudo launchctl bootout system "$D" 2>/dev/null || true
      sudo launchctl bootstrap system "$D" 2>/dev/null || { sleep 2; sudo launchctl bootstrap system "$D"; }
    done
  fi
  echo "Static hostname — current: $(scutil --get HostName 2>/dev/null || echo unset)"
  read -r -p "  set HostName/LocalHostName/ComputerName to (empty = keep): " hn
  if [ -n "$hn" ]; then
    # all three: LocalHostName is the Bonjour name behind <name>.local
    for k in HostName LocalHostName ComputerName; do sudo scutil --set "$k" "$hn"; done
  fi
fi

cat <<'EOF'

Done. By hand (SETUP.md says why):
  - gh auth login && gh auth setup-git
  - ~/.claude: attach dot-claude-config (§2c "Claude Code on macOS", owner)
  - Karabiner-Elements: approve driver + Input Monitoring (§2c "Keyboard")
EOF
[ $SERVER = 1 ] && cat <<'EOF'
  server role (§3b):
  - tailscale up --hostname=<name>
  - Settings → General → Sharing: Remote Login + Screen Sharing
  - SSH keys only: other machine's key from `gh api user/keys` → authorized_keys,
    log in with it FIRST, then sshd_config.d/010-machine-setup.conf (§3b)
  - Settings → Battery → Charging: 80% limit (docked machine)
  - UTM: open it ONCE on the screen (Gatekeeper), allow Automation for
    utmctl and for SSH; then create the "Home Assistant" VM (§3b
    "UTM VM at login")
  - heartbeat: an Uptime Kuma Push monitor (300 s, 1 retry; mra-mac: mra-server
    docs/49-mra-mac.md) or a healthchecks.io check (period 5 min / grace 10 min)
    → its push/ping URL into ~/.config/machine-setup/healthcheck-url
    (chmod 600; never the repo)
  - App Store sign-in → sudo mas install 497799835 (Xcode) → §3b Xcode steps
    (first launch brings an iOS runtime — don't -downloadPlatform on top)
EOF
echo "Then: machine-verify"
