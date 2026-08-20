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
  earlyoom \
  snapper \
  libdnf5-plugin-actions

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

echo "== disk overflow swap tier (see SETUP.md — zram stays primary) =="
# Own subvolume: a swapfile inside the root subvolume makes every btrfs
# snapshot of / fail (ETXTBSY) — see the swapfile TRAP in SETUP.md.
if [ ! -f /swap/swapfile ]; then
  sudo btrfs subvolume show /swap >/dev/null 2>&1 || sudo btrfs subvolume create /swap
  sudo chmod 700 /swap
  sudo btrfs filesystem mkswapfile --size 16g /swap/swapfile
  sudo swapon --priority 10 /swap/swapfile
  grep -q '^/swap/swapfile' /etc/fstab \
    || echo '/swap/swapfile none swap defaults,pri=10 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

echo "== snapper: pre/post snapshot pair around every dnf transaction =="
# python3-dnf-plugin-snapper is a DNF4 plugin — inert under dnf5; the dnf5
# way is the generic actions plugin + the hook file below (see SETUP.md).
if rpm -q python3-dnf-plugin-snapper >/dev/null 2>&1; then
  sudo dnf remove -y python3-dnf-plugin-snapper
fi
[ -f /etc/snapper/configs/root ] || sudo snapper -c root create-config /
sudo install -Dm644 assets/snapper.actions /etc/dnf/libdnf5-plugins/actions.d/snapper.actions

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
echo "  swapon --show               -> zram size per min(ram/2, 12288) after reboot; /swap/swapfile pri 10"
echo "  sudo snapper list           -> pre/post pair per dnf transaction (after the next one)"
echo "  sysctl vm.swappiness        -> 150"
echo "  journalctl -u earlyoom -b | grep SIGTERM  -> 10%/10% thresholds"
echo
echo "Now apply the judgment items from SETUP.md (PWAs, hardware section, etc.)."
