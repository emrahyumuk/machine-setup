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
  mRA Notes. Each PWA profile is separate on purpose (session isolation).
  Per-PWA tip: enable "Open out-of-scope URLs in a default browser" (pref
  `firefoxpwa.openOutOfScopeInDefaultBrowser`, default false) or external
  links open inside the PWA window. To replace a PWA's icon, overwrite the
  `~/.local/share/icons/hicolor/*/apps/FFPWA-<id>.png` files (ImageMagick
  from an SVG) + `gtk-update-icon-cache` — never edit the .desktop Icon=
  line, so firefoxpwa regenerations don't undo it.
- **WhatsApp lives in a CHROME PWA, not here** (moved 2026-08-18): in the
  Firefox PWA outgoing messages intermittently stalled (WebSocket recovery
  after suspend/background); WhatsApp Web treats Chromium as first-class.
  Install: web.whatsapp.com in Chrome → address-bar Install button → allow
  notifications. Chrome manages the desktop entry and icon itself — keep its
  stock icon; a custom one gets silently reverted on manifest refreshes.
  (History: replaced the karere flatpak wrapper 2026-07-30 — same ~700 MB
  content cost either way, WhatsApp Web is just heavy.)
- WHY firefoxpwa over a manual Chromium `--app=` window for the other PWAs:
  on Wayland, Chromium ignores `--class` → wrong dock icon unless forced to
  XWayland. firefoxpwa generates correct desktop entries natively. (A real
  Chrome PWA *install* is fine — Chrome manages its own entry, as WhatsApp
  shows — but mra-agent/mRA Notes stay on the Firefox engine on purpose:
  session isolation + uBlock.)

### Google Calendar via CalDAV (GNOME Online Accounts / Thunderbird / any client)
- TRAP: after connecting the Google account, only the default calendar shows
  up. Google exposes over CalDAV only the calendars ticked on its half-hidden
  sync page — secondary and shared calendars ship unticked.
- FIX: https://calendar.google.com/calendar/syncselect → tick everything
  wanted → save. Then enable them in the client (GNOME Calendar: hamburger →
  Manage Calendars). Sync may lag a few minutes.
- This is account-level state at Google, not client config — re-check it on
  a fresh machine only if calendars are missing again (it usually persists).
- App verdict (2026-08): GNOME Calendar is enough as the viewer; Evolution
  shares the same evolution-data-server backend so switching buys no sync
  gain — only reach for it (or Thunderbird's calendar) for meeting RSVPs or
  event search.

### Claude Code
- **The whole `~/.claude` config surface syncs via a private repo** (OWNER
  ONLY — the repo is private; new machine: clone it as `~/.claude` before
  first launch): github.com/emrahyumuk/dot-claude-config.
  The PORTABLE part for anyone else is the pattern, not the repo: version
  `~/.claude` with an allowlist .gitignore — ignore `/*`, then whitelist
  CLAUDE.md, settings.json, skills/, rules/, agents/, commands/, hooks/,
  bin/, and `projects/*/memory/` — so sessions, credentials and caches
  structurally can never enter; push it to a private remote of your own.
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
  ASSUMES: zram as the PRIMARY swap tier (since 2026-08-06 a low-priority
  disk overflow file sits beneath it — see the next entry; swappiness=150
  still steers reclaim into zram first). Do NOT port swappiness=150 to a
  machine whose primary swap is disk — it would thrash it. Hibernation
  remains unconfigured (a btrfs swapfile would need resume-offset plumbing;
  not wanted).
  VERIFY: `swapon --show` shows the new size; under load
  `/proc/pressure/memory` stays ~0 and swap-in rate stays low. Judge by
  pressure/traffic, NEVER by swap fullness (full-but-quiet zram is healthy).
  NOTE: `systemctl restart systemd-zram-setup@zram0` flushes zram back to RAM —
  transient pressure spike, save work first (or just reboot later).

### Disk overflow swap tier (the wall remover)
- 16 GB btrfs swapfile at priority 10 under zram's 100:
  ```
  btrfs filesystem mkswapfile --size 16g /swapfile
  swapon --priority 10 /swapfile
  # /etc/fstab: /swapfile none swap defaults,pri=10 0 0
  ```
  WHY (and the honest history — REJECTED TWICE before being added
  2026-08-06): rejected 07-31 as a thrashing fix (the sysctl tuning was the
  real fix) and 08-04 as a freeze fix (panic-time eviction through LUKS =
  the kcryptd storm). What changed: with calm watermarks + earlyoom in
  place, a LOW-PRIORITY overflow tier only ever receives cold pages as a
  background trickle — a different mechanism from panic eviction, and
  AES-NI absorbs the trickle invisibly. New evidence forced the revisit:
  24 earlyoom kills in ~15h and one hard freeze showed the recurring
  problem was the WALL itself (zram's hard ceiling). Windows and macOS
  never hit this failure class because both ship auto-growing swap; this
  tier gives Fedora the same "degrade, never die" behavior. The BIOS UMA
  reclaim (+4-6 GB) was considered and DECLINED at the time — the 8 GB
  iGPU reserve stayed for local-LLM plans; the swapfile alone removed the
  wall. (Reversed 2026-08-20: UMA lowered to 4 GB after a week of OOM
  storms — see the hardware section.)
  ASSUMES: btrfs (mkswapfile handles NOCOW/compression); LUKS cost is
  per-page AES-NI, negligible at trickle rates.
  VERIFY: `swapon --show` → two rows, zram pri 100, /swapfile pri 10,
  swapfile USED stays ~0 except under genuine overflow.
  FIELD-PROVEN 2026-08-11: first real overflow day — 18 parallel agent
  processes, zram full at 10.6/11.6 GB, 3.6 GB spilled to the swapfile,
  memory PSI 0.00 the whole time, zero UI impact. The exact workload class
  that froze the machine on 08-04 now degrades silently.

### Desktop responsiveness under full CPU load (agents/builds)
- MECHANISM (understand before touching): systemd user slices arbitrate CPU
  only under contention. `session.slice` (gnome-shell + Xwayland) vs
  `app.slice` (every GUI app incl. terminals and whatever agents spawn) vs
  `background.slice`. Fedora's `uresourced` daemon actively manages these:
  session.slice CPUWeight=500 vs app default 100, plus a focused-window
  boost (300) via `[AppBoost]` — it OVERRIDES manual
  `systemctl --user set-property` at runtime, so tune via
  `/etc/uresourced.conf` `[SessionSlice] CPUWeight=`, not drop-ins.
- FIELD STATUS 2026-08-12: the stock 500 is sufficient — 8-core build
  bursts no longer stutter the desktop. A 2026-08-10 stutter was initially
  blamed on scheduling but coincided with a rigo main-loop leak eating a
  core; with that gone, no reproduction. A user drop-in raising it to 1000
  exists (`~/.config/systemd/user/session.slice.d/50-ui-priority.conf`) but
  uresourced overrides it — left as documentation of the escalation path.
- IF stutter under load ever reproduces WITHOUT a leaking process: raise
  `[SessionSlice] CPUWeight=1000` in /etc/uresourced.conf and restart
  uresourced; next rung is a sched_ext interactive scheduler
  (`scx_bpfland`, COPR) — kernel supports it (CONFIG_SCHED_CLASS_EXT=y).
- Related finding: weights can't help INSIDE one scope — an app that spawns
  its own heavy children (a terminal's builds, an agent studio's agents)
  competes with them 1:1 in its own cgroup; the fix belongs in that app
  (spawn children into their own transient scope).
  VERIFY: `cat .../session.slice/cpu.weight` → 500 (uresourced's value).

### OOM defense — earlyoom (the anti-freeze layer)

- Install `earlyoom`, enable the service, and
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
  KILL NOTIFICATIONS: earlyoom's own `-n` is inert here — `systembus-notify`
  is retired from Fedora repos (F44) AND earlyoom's `DynamicUser=true`
  sandbox couldn't reach the session anyway. Instead `earlyoom-notify.sh`
  (user service, ships in this repo) tails the journal for
  `sending SIG(TERM|KILL) to process` and notify-sends each kill. The
  "to process" part matters: startup lines also say "sending SIGTERM when…"
  and would false-fire on every boot. Works because the user is in wheel
  (system journal readable).
  ASSUMES: zram-primary swap (the `-s` thresholds now span zram + the disk
  overflow tier — total swap must ALSO drain below 10% before a kill, which
  makes earlyoom a true last resort rather than a frequent visitor).
  VERIFY: `journalctl -u earlyoom -b | grep "sending SIGTERM"` shows the
  10%/10% thresholds; `systemctl --user is-active earlyoom-notify` → active;
  `oomctl` still shows only /system.slice (expected).

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

### Static hostname — the Chromium singleton-lock trap

**Set a static hostname on day one, before apps ever run:**
`sudo hostnamectl set-hostname mra-fedora` (any stable name). Fedora leaves
it unset by default; the transient hostname then follows the network (DHCP
hands out the IP as the name), so the machine flip-flops between e.g.
`fedora` and `192.168.1.5`.

Why it matters: every Chromium-based app (Chrome, and via Electron/CEF also
Spotify, Discord, Bitwarden, Unity Hub, custom `--user-data-dir` app
windows…) guards its profile with a `SingletonLock` symlink named
`<hostname>-<pid>`. A stale lock (unclean exit) is only reclaimed when the
hostname matches; under a *different* hostname the app assumes the profile
is open on another machine (NFS-home caution) and exits SILENTLY — icon
click does nothing, no error, `flatpak run` exits 0. Six apps hit this here
in one week.

**If the hostname ever changes on a live machine**, sweep the stale locks
once (covers flatpaks, dot-config apps, and custom browser profiles):

```sh
find ~/.var/app ~/.config ~/.local/share ~/.cache -maxdepth 5 \
  -name SingletonLock 2>/dev/null | while read f; do
  [ "$(readlink "$f" | sed 's/-[0-9]*$//')" != "$(hostname)" ] \
    && rm -fv "${f%Lock}"{Lock,Cookie,Socket}
done
```

Caveat: don't judge staleness by PID liveness — flatpak apps write their
sandbox-namespace PID (e.g. `-4`), which looks dead from the host while the
app is running. Hostname mismatch is the reliable test; skip apps that are
currently running (their lock regenerates on their next clean restart).

### Update cadence — one weekly ritual, four channels

- Updates arrive via dnf (system + vendor repos), flatpak, fwupd (firmware)
  and npm -g (agent CLIs). GNOME Software is a FRONTEND over the first
  three, not a fifth channel — its notifications are informational only.
- The ritual, Sunday evening, then the (already planned) weekly reboot —
  shipped as two zshrc functions (see `dotfiles/zshrc`): **`upcheck`**
  (what's pending, all four channels, one screen) and **`upall`**
  (apply everything).
- A user timer (`update-check.timer`, Sun 18:00, Persistent=true) runs
  `update-check.sh` → one desktop notification summarizing pending counts
  across all four channels; doubles as the ritual reminder. Files ship in
  this repo (script at root, units in assets/), installed by bootstrap.
- TRAP (root cause found 2026-08-06): npm's `allowScripts` policy BLOCKS
  postinstall scripts of npm-installed CLIs — the tool then dies with
  "native binary not installed" on every invocation. Permanent fix:
  `npm config set allow-scripts=opencode-ai,protobufjs,re2 --location=user`.
  (claude-code was the original victim and had a self-heal step in `upall`;
  both retired 2026-08-17 when it moved to the native installer.)
- Fedora RELEASE upgrades (44→45) are a separate twice-yearly event: wait
  ~2-3 weeks after release, then `dnf system-upgrade`; afterwards walk the
  VERIFY lines in this manifest.
  WHY weekly not daily: no measurable benefit to chasing updates daily on a
  desktop; weekly + reboot picks up kernels/mesa at a humane failure rate.
  VERIFY: `systemctl --user list-timers update-check.timer` shows next Sun.

### PipeWire sample rates — REVERTED same day, keep the default fixed 48 kHz
- `allowed-rates = [44100 48000 88200 96000]` was tried 2026-08-06 (let the
  graph follow content so 44.1 material reaches the DAC without a double
  resample) and REVERTED within hours: with EasyEffects in the chain, every
  graph rate switch (a 48 kHz notification joining while Spotify holds 44.1)
  produced audible crackling. Confirmed by A/B: runtime
  `pw-metadata -n settings 0 clock.force-rate 48000` stopped it instantly.
  Verdict: the double-resample cost is inaudible, the rate-switch glitches
  are not — PipeWire's fixed-48k default is correct FOR THIS MACHINE (an
  EasyEffects-free machine may judge differently).
  TRAP (still true, kept for the record): restarting pipewire kills the
  user's EasyEffects service AND can break EasyEffects' stream capture — a clean
  EasyEffects restart is required after any pipewire disruption, or output
  bypasses the DSP chain entirely ("sounds like bypass").
  VERIFY: `pw-metadata -n settings | grep allowed-rates` → no match.

### Already-default safety layers (verify present, don't install)
- systemd-oomd active, uresourced active, fstrim.timer enabled. These are
  Fedora Workstation defaults — just confirm after install.

---

## 3. Hardware-specific — ThinkPad P14s Gen6 AMD

**Nothing here auto-ports. Re-evaluate each item on new hardware.**

- **BIOS UMA frame buffer: 4 GB to iGPU** (Config → Display → Total
  Graphics Memory). Was 8 GB for local-LLM headroom; halved 2026-08-20
  after a week of memory storms (38 earlyoom kills in 12h at the worst) —
  the +4 GB of system RAM wins every day, while GTT still lets the iGPU
  address ~13.8 GB dynamically (~17.8 GB total), so the local-LLM envelope
  survives. Revert is one BIOS visit if a runtime ever truly needs 8 GB
  dedicated.
- **Qudelix 5K DAC**: WebHID over USB (not Bluetooth) for the config app;
  needs a udev rule; pipewire profile analog-stereo. Listening-chain rules
  (all three found violated 2026-08-06, together = "sounds worse than the
  Mac did"):
  - Keep the PipeWire sink pinned at **100%** — it had drifted to 91%
    (−2.37 dB digital attenuation). Do volume on the Qudelix's own
    buttons/app, never in software. DRIFT VECTOR: the keyboard volume keys
    write to the default sink, so one habitual key-press reintroduces the
    attenuation — that is how it drifts, not a bug.
    VERIFY (Qudelix connected as default):
    `wpctl get-volume @DEFAULT_AUDIO_SINK@` → 1.00.
  - (historical: while EasyEffects existed, a `bypass` autoload per device
    profile kept speaker EQ off the headphones — moot since EasyEffects' removal,
    kept as the pattern for any future system-wide DSP tool)
  - Streaming apps' settings are LOCAL per machine: after any machine move,
    re-check Spotify's "Normalize volume" (off for critical listening) and
    streaming quality (Very High) — they do not sync with the account.
  The EQ itself lives in the Qudelix's own flash — nothing to migrate.
- **Speakers: quiet by hardware, and that is FINAL — the DSP boost was
  RETIRED 2026-08-06.** ALC257 with no smart amp; ALSA already at 0.00 dB.
  An EasyEffects chain (loudness + bass_enhancer + limiter) spent two weeks
  (07-23 → 08-06) trying to buy loudness and lost the A/B: at any crackle-free
  gain it matched bypass loudness while sounding muddier — cone excursion
  is the ceiling, DSP only smears past it. EasyEffects was then removed
  entirely (see APPS.md "Removed on purpose"). Lessons kept: a limiter
  release of 5 ms grinds bass wavelengths into audible crackle (60 ms+ if
  a limiter ever returns); manual knob turns are NOT saved into presets —
  persistence lives in the preset file; keep the sink at exactly 100%
  (no EasyEffects limiter to catch over-unity clipping anymore).
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
