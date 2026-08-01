# Machine Setup Manifest

Owner: emrahyumuk
Current reference machine: ThinkPad P14s Gen6 AMD (21QMS1BQ00) · Fedora 44 · GNOME 50 · Wayland · LUKS btrfs

This file records **WHAT** was set up, **WHY**, and **HOW TO VERIFY** — not exact
commands. Commands rot; intent doesn't. To apply on a new machine, feed this file
to an AI with: *"Apply this manifest to this machine — adapt each item to the
current OS/hardware, respect every ASSUMES line, skip anything already satisfied,
and verify each item with its VERIFY line."*

Layers:
1. [Personal](#1-personal--any-machine-any-os) — travels everywhere
2. [OS: Fedora](#2-os-specific--fedora) — port to other Linux with care
3. [Hardware](#3-hardware-specific--thinkpad-p14s-gen6-amd) — does NOT auto-port; re-evaluate per machine
4. [Deliberately NOT done](#4-deliberately-not-done) — decisions against, with reasons

---

## 1. Personal — any machine, any OS

### Shell & terminal
- zsh, Ghostty terminal. Catppuccin Mocha lives ONLY in Ghostty's own config
  (app-internal) — desktop stays stock theming (see §2 theming trap).

### dnf tweaks (or the OS's package manager equivalent)
- `max_parallel_downloads=10` in `/etc/dnf/dnf.conf`.

### Rust toolchain
- **mold linker, global**: `~/.cargo/config.toml`:
  ```toml
  [target.x86_64-unknown-linux-gnu]
  rustflags = ["-C", "link-arg=-fuse-ld=mold"]
  ```
  WHY: GNU ld is mostly single-threaded; Tauri binaries relink fully on every
  incremental build. mold cuts the link 5-10x → shorter full-power windows,
  less heat. No clang needed (gcc ≥ 12 supports `-fuse-ld=mold`).
  VERIFY: build anything, then `readelf -p .comment <binary> | grep mold`.
  NOTE: changing rustflags invalidates cargo's cache — first build after is full.

### Firefox
- Default browser. Second profile ("Music") launched as its own app with pinned
  profile selection — for music/media isolation.
- **PWAs via firefoxpwa** (PWAsForFirefox extension + native host): mra-agent,
  mRA Notes, WhatsApp. Each PWA profile is separate on purpose (session isolation).
- **WhatsApp PWA specifics**:
  - Icon: WhatsApp logo SVG (`assets/whatsapp.svg` in this repo — this exact
    file is what the dock icon is generated from).
    Generate all FFPWA-<id> icon sizes from it with ImageMagick
    (`magick -background none <svg> -resize NxN -gravity center -extent NxN`),
    overwrite files under `~/.local/share/icons/hicolor/*/apps/FFPWA-<id>.png`,
    then `gtk-update-icon-cache`. Do NOT edit the .desktop Icon= line — replace
    the files it points to, so firefoxpwa regenerations don't undo it.
  - Setting: enable "Open out-of-scope URLs in a default browser" in the PWA's
    own settings page (pref `firefoxpwa.openOutOfScopeInDefaultBrowser`, default
    is false). Otherwise external links open inside the WhatsApp window.
  WHY PWA over a wrapper app (karere etc.): same ~700 MB content cost either way
  (WhatsApp Web is just heavy), but one less flatpak to maintain, Firefox engine
  security updates, uBlock works. NOT a memory win — measured ±0.
- WHY firefoxpwa over Chromium `--app=`: on Wayland, Chromium ignores `--class`
  → wrong dock icon unless forced to XWayland. firefoxpwa generates correct
  desktop entries natively.

### Claude Code
- Global prefs in `~/.claude/CLAUDE.md` (Turkish responses, human-voice for
  authored text, separator formatting). Memory dir has machine quirks — worth
  copying `fedora_desktop_quirks.md` content into new machines' context.

---

## 2. OS-specific — Fedora

### RPM Fusion + hardware video decode (BIG one)
- Enable RPM Fusion free + nonfree, then install `mesa-va-drivers-freeworld`.
  WHY: stock Fedora mesa ships with H.264/HEVC VA-API decode stripped (patent
  policy). Every H.264 stream (Twitch, X, Instagram, most MP4) falls back to
  software decode. Measured on reference machine: 83°C / 4990 RPM fan / 24 W
  package → after fix 51°C / 3264 RPM / 9 W with the same stream. Also unlocks
  HEVC Main/Main10 decode and H.264 *encode* (OBS, video calls).
  NOT browser-specific — Chrome uses the same VA-API layer; switching browsers
  never fixes it.
  VERIFY: `vainfo | grep -c H264` → must be > 0. Restart browser fully after.
  ASSUMES: AMD/Intel iGPU using mesa. (F44: no `dnf swap` needed — stock VA
  driver lives inside mesa-dri-drivers; plain `dnf install` of freeworld works.)

### zram + VM tuning
- `/etc/systemd/zram-generator.conf`:
  ```ini
  [zram0]
  zram-size = min(ram / 2, 12288)
  ```
- `/etc/sysctl.d/99-zram-tuning.conf`:
  ```ini
  vm.swappiness = 150
  vm.page-cluster = 0
  vm.watermark_boost_factor = 0
  vm.watermark_scale_factor = 125
  ```
  WHY: Fedora ships zram with disk-era VM defaults. Measured failure mode:
  8 GB zram nearly full + app launch burst (Spotify, 1.3 GB) → emergency
  reclaim storm (kswapd 20% + LUKS kcryptd 33% + btrfs-endio 18%, CPU pegged,
  real thrashing 615 pages/s in AND out). swappiness=60 prefers evicting page
  cache (refill goes through LUKS = expensive) over zram compression (pure CPU,
  cheap); page-cluster=3 is rotational-disk batching, waste on zram;
  watermark_scale=125 makes kswapd start early and calm — this is the knob that
  kills the burst-allocation stall. zram cap raise costs nothing until used
  (DISKSIZE is a cap, not a reservation; measured lzo-rle ratio 2.75:1).
  Field result: fan stays off in normal use; full-core rustc build with mem PSI
  and swap traffic both zero.
  ASSUMES: zram-only swap AND no hibernation (hibernate needs disk swap and is
  impossible with zram-only anyway). Do NOT port swappiness=150 to a machine
  without zram — it would thrash disk swap.
  VERIFY: `swapon --show` shows the new size; under load
  `/proc/pressure/memory` stays ~0 and swap-in rate stays low. Judge by
  pressure/traffic, NEVER by swap fullness (full-but-quiet zram is healthy).
  NOTE: `systemctl restart systemd-zram-setup@zram0` flushes zram back to RAM —
  transient pressure spike, save work first (or just reboot later).

### OOM defense — earlyoom (the anti-freeze layer)

- Install `earlyoom` + `systembus-notify` (the latter is what makes `-n`
  desktop notifications actually reach the session), enable the service, and
  replace `/etc/default/earlyoom` with: Fedora's stock `--avoid` list KEPT
  WHOLE and extended with the terminal (`ghostty`), `--prefer` extended with
  `java|chrome|code` (restartable heavyweights die first), thresholds
  `-r 3600 -m 10,5 -s 10,5 -n`, and **no `-M`**.
  WHY: 2026-08-04 hard freeze (power-button reset). Journal showed zero OOM
  kills — classic thrashing livelock: near exhaustion the kernel evicts
  executable pages and faults them straight back, nothing counts as
  unreclaimable, so the kernel OOM killer never fires. systemd-oomd was
  "active" but `oomctl` proved it monitors ONLY /system.slice — Fedora ships
  user-side config (kill@80% in `/usr/lib/systemd/user/slice.d/`) yet those
  slices never reach oomd's monitored set, so the entire user session
  (browsers, agents, builds) was unguarded. earlyoom watches raw
  MemAvailable+SwapFree, ignores cgroups entirely, and SIGTERMs the single
  largest process — surgical, freeze-proof.
  TRAPS baked into the config: Fedora's default `-m 4 -M 409600` fires far
  too late (~940 MB / 400 MB floor on this box); with both `-m` and `-M`
  set the SMALLER threshold wins, so `-M` must be dropped for `-m 10` to
  mean anything; replacing (rather than extending) the stock avoid-list
  would strip protection from `dnf`/`packagekitd`/`cryptsetup`.
  REJECTED alternatives: a `user@.service.d` oomd drop-in (oomd kills whole
  cgroup subtrees — an entire terminal scope with every tab; Fedora itself
  retreated from that config) unless a freeze recurs WITH earlyoom active;
  a disk swap tier (reintroduces the LUKS kcryptd storm the zram tuning
  eliminated). Note `node` is deliberately NOT in `--prefer` — agent
  sessions shouldn't be first victims (they resume, but still).
  ASSUMES: zram-only swap (the `-s` thresholds are sized for it).
  VERIFY: `journalctl -u earlyoom -b | grep "sending SIGTERM"` shows the
  10%/10% thresholds; `oomctl` still shows only /system.slice (expected).

### Theming discipline (GNOME 50 traps, hard-won)
- Stock shell theme, stock GTK, `accent-color` only. WHY: a stale shell theme
  (Catppuccin CSS written for GNOME 46) silently corrupted widget layout on
  GNOME 50 and looked exactly like a GPU artifact — cost hours. GTK4/libadwaita
  ignores `gtk-theme` anyway. When shell widgets look wrong: check theme's date
  against `gnome-shell --version` BEFORE debugging the GPU.
- **Dark mode has a GTK3 blind spot**: GNOME's `color-scheme=prefer-dark` is
  read by GTK4/libadwaita apps only. Electron apps' GTK3 chrome (window
  frame, menu bar) reads the old flag instead — without it, dark system +
  light titlebars. Fix is `~/.config/gtk-3.0/settings.ini`:
  ```ini
  [Settings]
  gtk-application-prefer-dark-theme=1
  ```
  (tracked verbatim in `dotfiles/gtk3-settings.ini`)
  These are a LINKED PAIR: GNOME's Dark Style toggle does NOT touch this
  file — switching the system to light requires flipping the flag to 0 by
  hand, or Electron chrome stays dark. There is no auto day/night theme
  switching in GNOME (Night Light is color temperature, not theme).
  VERIFY: restart an Electron app (Discord/VS Code) → titlebar/menus dark.
- `kernel.dmesg_restrict=1` on Fedora → use `journalctl -k`, not dmesg.
- GNOME extension schemas are invisible to plain `gsettings list-schemas` —
  keybinding conflicts hide in extension schemas (`--schemadir` needed).

### Already-default safety layers (verify present, don't install)
- systemd-oomd active, uresourced active, fstrim.timer enabled. These are
  Fedora Workstation defaults — just confirm after install.

---

## 3. Hardware-specific — ThinkPad P14s Gen6 AMD

**Nothing here auto-ports. Re-evaluate each item on new hardware.**

- **BIOS UMA frame buffer: 8 GB to iGPU — deliberate, keep.** OS sees 23 of
  32 GB. Kept for local LLM experiments (some runtimes want dedicated VRAM;
  GTT gives ~11.6 GB more dynamically → ~19.6 GB addressable). If local LLM
  plans die, lowering it in BIOS returns ~6 GB to the system.
- **Qudelix 5K DAC**: WebHID over USB (not Bluetooth) for the config app;
  needs a udev rule; pipewire profile analog-stereo.
- **EasyEffects speaker boost**: load-bearing for the quiet built-in speakers
  (ALC257, no smart amp — DSP is the only volume headroom). Keep the app
  running but its WINDOW CLOSED (open window costs CPU).
- **Battery charging: the Battery-Health-Charging extension OWNS the
  thresholds — never touch GNOME Settings → Power → "Battery Charging".**
  Both write the same firmware knobs (`charge_control_{start,stop}_threshold`);
  last writer wins, and GNOME's radio doesn't recognize extension-set values
  (it shows "Maximize Charge" while firmware actually holds 80/75 — verified
  2026-08-01). Daily: Balanced (80/75). Before a long unplugged day: flip to
  Full Capacity ~1h ahead, back to Balanced when re-docked. Maximum Lifespan
  (~60%) exists for weeks-long docked stretches — optional. Staying plugged
  at the cap is harmless (charge bypass). Avoid regular deep discharges below
  ~15-20%; a full 100→20→100 cycle every 2-3 months recalibrates the gauge.
  VERIFY: `cat /sys/class/power_supply/BAT0/charge_control_end_threshold` → 80.
- **Fingerprint reader**: enrolled for sudo. Quirk: sudo inside embedded
  terminals/AI sessions may lack a TTY for password fallback — run sudo
  commands in a real terminal window.
- **NPU (XDNA2)**: Lemonade stack serves local models on localhost:13305.
  Good for small/fast tasks; RAM is the model-size ceiling, not TOPS.
- Thermal envelope reference (healthy): idle ~45-52°C, fan off or ~2400 RPM;
  full-core rustc ~82°C / 4990 RPM is NORMAL (throttle at 95+). Fan hysteresis:
  spins up fast, ramps down slowly — a loud fan minutes after load ended is
  soak, not a problem.

---

## 4. Deliberately NOT done

- **Shared cargo target-dir** (`CARGO_TARGET_DIR`): cargo takes a coarse lock
  on the build dir → parallel builds from multiple AI-agent sessions would
  SERIALIZE. Bad fit for a multi-agent workflow. Revisit only if disk < 50 GB
  free or a second Rust project appears.
- **`[build] jobs = N` cap**: deferred. Try mold first; cap parallelism only
  if heat still bothers after.
- **TLP**: conflicts with power-profiles-daemon + amd-pstate EPP. ppd works.
- **Custom kernels (CachyOS etc.)**: maintenance cost > benefit on a
  LUKS + Secure Boot machine.
- **preload, zswap, noatime**: obsolete / conflicts with zram / unmeasurable.
- **Disk swapfile**: considered twice. Rejected in favor of zram tuning above —
  the tuning addressed the measured mechanism directly; a swapfile would only
  have absorbed overflow. Reconsider only if thrashing recurs WITH the tuning.
- **system76-scheduler / ananicy-cpp**: no measured UI starvation during
  builds. Install ananicy-cpp only if that complaint actually appears.
- **Power profile stays `balanced`**: power-saver would mask load problems
  instead of fixing them (the real fixes were VA-API + app-level).
