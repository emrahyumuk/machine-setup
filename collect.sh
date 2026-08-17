#!/bin/bash
# Regenerates inventory/ from the current machine state.
# Run after installing/removing things; review the diff, then commit.
#
# PRIVACY RULE: inventory holds CONFIG (deliberate choices), never STATE.
# Pairing data, certificates, device ids, caches never land here. dconf is
# therefore a whitelist — add a namespace only after reading its dump.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p inventory

echo "== system =="
{
  echo "collected: $(date -I)"
  . /etc/os-release && echo "os: $PRETTY_NAME"
  echo "kernel-at-collect: $(uname -r)   # informational only, rolls constantly"
  echo "model: $(cat /sys/devices/virtual/dmi/id/product_family 2>/dev/null || true) ($(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true))"
} > inventory/system.txt

echo "== dnf user-installed (RAW appendix — curated view lives in APPS.md) =="
# .collect-exclude (gitignored, one package name per line) keeps
# not-yet-public items out of the published inventory
dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | sort -u \
  | { [ -f .collect-exclude ] && grep -vxf .collect-exclude || cat; } \
  > inventory/packages-dnf-raw.txt

echo "== flatpaks =="
flatpak list --app --columns=application,origin 2>/dev/null | sort > inventory/flatpaks.txt

echo "== gnome extensions (annotations live in APPS.md) =="
{
  echo "# enabled"
  gnome-extensions list --enabled 2>/dev/null | sort
  echo "# installed but disabled"
  comm -23 <(gnome-extensions list 2>/dev/null | sort) <(gnome-extensions list --enabled 2>/dev/null | sort)
} > inventory/gnome-extensions.txt

echo "== gnome settings (whitelisted namespaces) =="
{
  echo "# Whitelist only — see privacy rule in collect.sh."
  echo "# GSConnect is EXCLUDED on purpose: its dconf tree is pairing STATE"
  echo "# (device certificate, ids, phone name, local IP). On a new machine:"
  echo "# install GSConnect, pair the phone manually."
  echo
  for ns in \
    /org/gnome/desktop/interface/ \
    /org/gnome/shell/keybindings/ \
    /org/gnome/desktop/wm/keybindings/ \
    /org/gnome/settings-daemon/plugins/media-keys/ \
    /org/gnome/shell/extensions/dash-to-dock/ \
    /org/gnome/shell/extensions/blur-my-shell/ \
    /org/gnome/shell/extensions/Battery-Health-Charging/ \
    /org/gnome/shell/extensions/vitals/ \
    /org/gnome/shell/extensions/caffeine/ \
    /org/gnome/shell/extensions/clipboard-indicator/ \
    /org/gnome/shell/extensions/user-theme/ \
  ; do
    echo "### dconf load $ns  <<'EOF'"
    dconf dump "$ns" 2>/dev/null
    echo "### EOF"
    echo
  done
} > inventory/gnome-settings.dconf

echo "== dev tool globals =="
# npm globals live under nvm's node. `command -v npm` is NOT a safe guard:
# non-interactive shells resolve npm to the system one (/usr/bin/npm, empty
# /usr/local prefix) and would overwrite the list with emptiness. Address
# nvm's newest npm explicitly instead.
nvm_bin=$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1)
if [ -n "$nvm_bin" ] && [ -x "$nvm_bin/npm" ]; then
  {
    echo "# npm -g"
    PATH="$nvm_bin:$PATH" "$nvm_bin/npm" ls -g --depth=0 --parseable 2>/dev/null | tail -n+2 | xargs -rn1 basename || true
  } > inventory/dev-globals.txt
else
  echo "  nvm npm not found — keeping the existing inventory list"
fi

echo "== dotfiles (verbatim copies; secrets-scan before commit) =="
mkdir -p dotfiles
cp ~/.zshrc dotfiles/zshrc
cp ~/.config/ghostty/config dotfiles/ghostty.config
cp ~/.config/gtk-3.0/settings.ini dotfiles/gtk3-settings.ini 2>/dev/null || true
# .gitconfig is NOT auto-copied: it contains identity (email).
# A sanitized template lives at dotfiles/gitconfig.template — update by hand.
if grep -rqiE "token|secret|password|api[_-]?key|BEGIN (RSA|EC|OPENSSH)" dotfiles/; then
  echo "!! possible secret in dotfiles/ — review before committing" >&2
fi

echo
echo "Done → inventory/ + dotfiles/. Review the diff before committing."
