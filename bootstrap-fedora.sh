#!/bin/bash
# Mechanical base only — the deterministic, judgment-free part of SETUP.md.
# Everything requiring judgment (tuning, hardware quirks, PWAs) lives in
# SETUP.md and is applied by reading it, not by this script.
# Idempotent: safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

echo "== RPM Fusion (free + nonfree) =="
if ! dnf repolist 2>/dev/null | grep -q rpmfusion-free; then
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi

echo "== dnf tweaks =="
grep -q "^max_parallel_downloads" /etc/dnf/dnf.conf \
  || echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf >/dev/null

echo "== packages =="
sudo dnf install -y \
  mesa-va-drivers-freeworld \
  libva-utils \
  mold \
  zsh \
  earlyoom

echo "== earlyoom (anti-freeze OOM layer — see SETUP.md for the full story) =="
# Stock Fedora avoid-list kept whole + ghostty; prefer extended with
# restartable heavyweights; NO -M (with -m and -M the smaller wins).
sudo tee /etc/default/earlyoom >/dev/null <<'EOF'
EARLYOOM_ARGS="-r 3600 -m 10,5 -s 10,5 -n --prefer '^(Web Content|Isolated Web Co|java|chrome|code)$' --avoid '^(dnf|packagekitd|gnome-shell|gnome-session-c|gnome-session-b|lightdm|sddm|sddm-helper|gdm|gdm-wayland-ses|gdm-session-wor|gdm-x-session|Xorg|Xwayland|systemd|systemd-logind|dbus-daemon|dbus-broker|cinnamon|cinnamon-sessio|kwin_x11|kwin_wayland|plasmashell|ksmserver|plasma_session|startplasma-way|sway|i3|xfce4-session|mate-session|marco|lxqt-session|openbox|cryptsetup|ghostty)$'"
EOF
sudo systemctl enable --now earlyoom
sudo systemctl restart earlyoom

echo "== earlyoom kill notifications (journal watcher) =="
# systembus-notify is retired from Fedora repos and earlyoom's DynamicUser
# sandbox can't reach the session anyway — a user-side journal tail can.
install -Dm755 earlyoom-notify.sh ~/.local/bin/earlyoom-notify.sh
install -Dm644 assets/earlyoom-notify.service ~/.config/systemd/user/earlyoom-notify.service
systemctl --user daemon-reload
systemctl --user enable --now earlyoom-notify.service

echo "== zram config =="
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = min(ram / 2, 12288)
EOF

echo "== VM tuning (see SETUP.md for rationale; ASSUMES zram, no hibernate) =="
sudo tee /etc/sysctl.d/99-zram-tuning.conf >/dev/null <<'EOF'
vm.swappiness = 150
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
EOF
sudo sysctl --system >/dev/null

echo "== PipeWire: content-following sample rates (see SETUP.md) =="
sudo mkdir -p /etc/pipewire/pipewire.conf.d
sudo tee /etc/pipewire/pipewire.conf.d/10-rates.conf >/dev/null <<'EOF'
context.properties = {
    default.clock.allowed-rates = [ 44100 48000 88200 96000 ]
}
EOF

echo "== weekly update summary notifier (Sun 18:00) =="
install -Dm755 update-check.sh ~/.local/bin/update-check.sh
install -Dm644 assets/update-check.service ~/.config/systemd/user/update-check.service
install -Dm644 assets/update-check.timer ~/.config/systemd/user/update-check.timer
systemctl --user daemon-reload
systemctl --user enable --now update-check.timer

echo "== cargo: mold as linker =="
mkdir -p ~/.cargo
if [ ! -f ~/.cargo/config.toml ]; then
  cat > ~/.cargo/config.toml <<'EOF'
[target.x86_64-unknown-linux-gnu]
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
EOF
else
  echo "  ~/.cargo/config.toml exists — merge manually (see SETUP.md)"
fi

echo
echo "Done. Verification:"
echo "  vainfo | grep -c H264       -> must be > 0 (needs relogin/reboot if 0)"
echo "  swapon --show               -> zram size per min(ram/2, 12288) after reboot"
echo "  sysctl vm.swappiness        -> 150"
echo "  journalctl -u earlyoom -b | grep SIGTERM  -> 10%/10% thresholds"
echo
echo "Now apply the judgment items from SETUP.md (PWAs, hardware section, etc.)."
