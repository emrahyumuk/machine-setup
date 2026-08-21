#!/bin/bash
# verify-fedora.sh — drift check: runs every VERIFY line of SETUP.md (Fedora
# + this hardware) and prints PASS / FAIL / SKIP. Read-only. Run plainly for
# the user-level checks; with sudo for the ones that need root (marked SKIP
# otherwise). Exit 1 if anything FAILs.
#
# WHY: two silent drifts were found by accident in Aug 2026 — snapper's dnf4
# plugin inert under dnf5 for a month, and the swapfile blocking every btrfs
# snapshot for two weeks. Neither makes noise. This does.
#
# Usage: ./verify-fedora.sh            (user-level)
#        sudo -E ./verify-fedora.sh    (everything; -E keeps $HOME)
#        machine-verify                (installed by bootstrap to ~/.local/bin)

pass=0; fail=0; skip=0
ok()   { printf '  \e[32mPASS\e[0m  %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \e[31mFAIL\e[0m  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; fail=$((fail+1)); }
skipc(){ printf '  \e[33mSKIP\e[0m  %s\n' "$1"; skip=$((skip+1)); }
sec()  { printf '\n\e[1m%s\e[0m\n' "$1"; }
U="${SUDO_USER:-$USER}"; H=$(getent passwd "$U" | cut -d: -f6)
root=0; [ "$(id -u)" = 0 ] && root=1
asuser() { if [ $root = 1 ]; then sudo -u "$U" env XDG_RUNTIME_DIR="/run/user/$(id -u "$U")" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$U")/bus" "$@"; else "$@"; fi; }

sec "§1 Personal"
[ "$(asuser xdg-mime query default application/vnd.apple.mpegurl 2>/dev/null)" = mpv.desktop ] \
  && ok "m3u8 → mpv" || bad "m3u8 → mpv" "xdg-mime default mpv.desktop application/vnd.apple.mpegurl …"
grep -q '^deinterlace=yes' "$H/.config/mpv/mpv.conf" 2>/dev/null && ok "mpv deinterlace=yes" || bad "mpv.conf deinterlace"
grep -q '^show_notifications = false' "$H/.config/starship.toml" 2>/dev/null && ok "starship notifications off" || bad "starship show_notifications must be false (agent-PTY storm)"
grep -q 'fuse-ld=mold' "$H/.cargo/config.toml" 2>/dev/null && ok "cargo → mold" || bad "~/.cargo/config.toml lacks mold"
n=$(asuser bash -lc 'which -a claude 2>/dev/null | sort -u | wc -l'); t=$(readlink -f "$H/.local/bin/claude" 2>/dev/null)
[ "$n" = 1 ] && [[ "$t" == "$H/.local/share/claude/"* ]] && ok "claude: single native install" || bad "claude install" "which -a claude → $n entries; ~/.local/bin/claude → ${t:-missing}"
grep -q 'allow-scripts=' "$H/.npmrc" 2>/dev/null && ok "npm allow-scripts set" || bad "~/.npmrc allow-scripts (postinstall trap)"
grep -q 'gtk-application-prefer-dark-theme *= *1' "$H/.config/gtk-3.0/settings.ini" 2>/dev/null && ok "gtk3 dark flag" || bad "gtk-3.0/settings.ini dark flag (Electron titlebars)"

sec "§2 Fedora"
[ -n "$(hostnamectl --static 2>/dev/null)" ] && ok "static hostname: $(hostnamectl --static)" || bad "static hostname unset" "hostnamectl set-hostname <name> (Chromium singleton-lock trap)"
grep -q '^max_parallel_downloads=10' /etc/dnf/dnf.conf && ok "dnf max_parallel_downloads=10" || bad "dnf.conf max_parallel_downloads"
rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1 && ok "mesa-va-drivers-freeworld" || bad "freeworld VA driver missing"
c=$(asuser vainfo 2>/dev/null | grep -c H264); [ "${c:-0}" -gt 0 ] && ok "vainfo H264 profiles: $c" || bad "vainfo shows no H264 (needs relogin after install?)"
rpm -q ffmpeg >/dev/null 2>&1 && ! rpm -q ffmpeg-free >/dev/null 2>&1 && ok "full ffmpeg (not ffmpeg-free)" || bad "ffmpeg: expected full ffmpeg, not ffmpeg-free"
z=$(zramctl --output DISKSIZE --noheadings 2>/dev/null | head -1 | tr -d " "); [[ "$z" == 12G* ]] && ok "zram 12G" || bad "zram size $z (expect 12G = min(ram/2,12288))"
for kv in vm.swappiness=150 vm.page-cluster=0 vm.watermark_boost_factor=0 vm.watermark_scale_factor=125; do
  k=${kv%=*}; v=${kv#*=}; [ "$(sysctl -n $k 2>/dev/null)" = "$v" ] && ok "$kv" || bad "$k=$(sysctl -n $k) (expect $v)"
done
swapon --show=NAME,PRIO --noheadings 2>/dev/null | grep -q '^/swap/swapfile *10$' && ok "swapfile /swap/swapfile pri 10" || bad "swapfile row" "swapon --show; expect /swap/swapfile pri 10"
[ "$(stat -c %i /swap 2>/dev/null)" = 256 ] && ok "/swap is its own subvolume" || bad "/swap not a subvolume (inode $(stat -c %i /swap 2>/dev/null)) — snapshots of / will fail"
systemctl is-active earlyoom >/dev/null 2>&1 && grep -q -- '-m 10,5 -s 10,5' /etc/default/earlyoom 2>/dev/null && ok "earlyoom active, 10%/10% thresholds" || bad "earlyoom service/args"
[ "$(asuser systemctl --user is-active earlyoom-notify.service 2>/dev/null)" = active ] && ok "earlyoom-notify (user) active" || bad "earlyoom-notify.service not active"
[ "$(asuser systemctl --user is-enabled update-check.timer 2>/dev/null)" = enabled ] && ok "update-check.timer enabled" || bad "update-check.timer not enabled"
[ "$(cat /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/session.slice/cpu.weight 2>/dev/null)" = 500 ] && ok "session.slice cpu.weight 500 (uresourced)" || bad "session.slice cpu.weight"
[ "$(asuser gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null)" = "''" ] && ok "shell theme empty (stock)" || skipc "user-theme name not '' or schema absent — check SETUP theming trap"
ar=$(asuser pw-metadata -n settings 2>/dev/null | grep -o "allowed-rates. value:'[^']*'" | sed "s/.*value://"); case "$ar" in ""|"'[ 48000 ]'") ok "pipewire rates: fixed 48 kHz (default)";; *) bad "pipewire allowed-rates $ar (SETUP: keep the fixed-48k default)";; esac
rpm -q libdnf5-plugin-actions >/dev/null 2>&1 && [ -f /etc/dnf/libdnf5-plugins/actions.d/snapper.actions ] && ok "dnf5 actions plugin + snapper hook" || bad "snapper hook" "libdnf5-plugin-actions + actions.d/snapper.actions"
rpm -q python3-dnf-plugin-snapper >/dev/null 2>&1 && bad "python3-dnf-plugin-snapper installed (dnf4-only, inert)" || ok "no dnf4 snapper plugin"
if [ $root = 1 ]; then
  snapper list 2>/dev/null | grep -q ' pre ' && snapper list | grep -q ' post ' && ok "snapper: pre/post pairs exist" || bad "snapper has no pre/post pairs — hook not firing (check /var/log/snapper.log, errno 26 = swapfile in /)"
else skipc "snapper pre/post pairs (needs sudo)"; fi
systemctl is-enabled fstrim.timer >/dev/null 2>&1 && ok "fstrim.timer" || bad "fstrim.timer"
first=$(efibootmgr 2>/dev/null | awk '/BootOrder/{split($2,a,","); print a[1]}'); lbl=$(efibootmgr 2>/dev/null | grep "^Boot$first" | sed 's/^Boot[0-9A-F]*\*\? *//; s/\t.*//')
[[ "$lbl" == *Fedora* ]] && ok "UEFI boots Fedora first ($first)" || skipc "UEFI first entry: ${lbl:-unknown} (dual-boot: Windows updates may reorder; efibootmgr -o …)"
[ "$(timedatectl show -p LocalRTC --value 2>/dev/null)" = yes ] && ok "RTC local (dual-boot, intentional)" || skipc "RTC not local — fine if Windows is gone"

sec "§3 Hardware (ThinkPad P14s Gen6)"
[ "$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)" = 80 ] && ok "charge cap 80%" || bad "charge_control_end_threshold $(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)"
[ -f /etc/udev/rules.d/70-qudelix.rules ] && ok "Qudelix udev rule" || bad "70-qudelix.rules missing"
v=$(cat /sys/class/drm/card1/device/mem_info_vram_total 2>/dev/null); [ -n "$v" ] && [ "$v" -le 4400000000 ] && ok "iGPU VRAM (UMA) $((v/1048576)) MB" || skipc "iGPU VRAM total: ${v:-?} bytes (expect ~4096 MB after the 2026-08-20 BIOS change)"

printf '\n%d pass, %d fail, %d skip\n' $pass $fail $skip
[ $fail -eq 0 ]
