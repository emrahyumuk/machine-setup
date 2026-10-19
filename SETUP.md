# Machine Setup Manifest

Owner: emrahyumuk
Current reference machine: ThinkPad P14s Gen6 AMD (21QMS1BQ00) · Fedora 44 · GNOME 50 · Wayland · LUKS btrfs

This file records **WHAT** was set up, **WHY**, and **HOW TO VERIFY** — not exact
commands. Commands rot; intent doesn't. To apply on a new machine, feed this file
to an AI with: *"Apply this manifest to this machine — adapt each item to the
current OS/hardware, respect every ASSUMES line, skip anything already satisfied,
and verify each item with its VERIFY line."*

Layers (one file on purpose — decisions read as one document; per-OS
mechanics live in `os/<os>/`, per-machine records in `machines/`):
1. [Personal](#1-personal--any-machine-any-os) — travels everywhere
2. [OS: Fedora](#2-os-specific--fedora) · [OS: Windows](#2b-os-specific--windows) (§2b, first session pending) · [OS: macOS](#2c-os-specific--macos) (§2c) — further OS layers as §2d…
3. [Hardware: ThinkPad P14s](#3a-hardware-specific--thinkpad-p14s-gen6-amd-thinkpad-p14s) — §3a · [Hardware: MacBook Pro 14" M2 Pro](#3b-hardware-specific--macbook-pro-14-m2-pro-mbp14) — §3b; §3c… per further machine; does NOT auto-port
4. [Deliberately NOT done](#4-deliberately-not-done) — decisions against, with reasons

---

## 1. Personal — any machine, any OS

### Shell & terminal
- zsh, Ghostty terminal. Catppuccin Mocha lives ONLY in Ghostty's own config
  (app-internal) — desktop stays stock theming (see §2 theming trap).
- starship prompt, config in `dotfiles/starship.toml` (Catppuccin powerline
  preset, `cmd_duration` with milliseconds). `show_notifications = false`
  on purpose: the "Command finished" desktop notification fires from EVERY
  shell that renders the prompt, and on a machine where agent sessions run
  dozens of zsh PTYs in parallel that is a notification storm (2026-08-21:
  ~15 identical "1m33s" toasts from one test run) — the duration is in the
  prompt anyway, and the agent tooling has its own attention notifications.
- mpv as the video player, config `dotfiles/mpv.conf` → `~/.config/mpv/`,
  and `.m3u8`/mp4/mkv/webm MIME types pointed at it (`xdg-mime default
  mpv.desktop …` — Fedora otherwise hands `.m3u8` to the music app).
  WHY the two non-default lines: `deinterlace=yes` because some live HLS
  streams are interlaced material encoded as progressive (fields woven, no
  flag) and comb badly in browsers and unfiltered players; `hwdec=vaapi-copy`
  instead of `auto-safe` because with pure hardware decode the GPU-side
  deinterlacer skips unflagged frames — measured 2026-08-21: software path
  clean, pure-hwdec path still combed. `-copy` keeps GPU decode and runs
  bwdif on the copied frames; the copy cost is invisible at 1080p.
  LIMIT: if a stream was already downscaled from interlaced source without
  deinterlacing (combing "baked in"), no player can fix it — that is the
  source's fault; `ffprobe`'s resolution flipping (1080→720) is the tell.
  VERIFY: `xdg-mime query default application/vnd.apple.mpegurl` →
  mpv.desktop; in mpv Shift+i shows "vaapi-copy" and Deinterlace: yes.

### Git — identity asked, config from the template
- `dotfiles/gitconfig.template` → `~/.gitconfig` (delta as pager with line
  numbers + Catppuccin theme, `zdiff3` conflicts, `pull.rebase`,
  `init.defaultBranch=main`), then the identity is set PER MACHINE and never
  committed: `git config --global user.name <name>` /
  `git config --global user.email <email>`. Owner's convention:
  `user.name` = the **Git host username** (e.g. the GitHub handle), not the
  full name — `git log`, `git blame` and GitHub then show one and the same
  identity; the email is what links commits to the account anyway.
  WHY a template + a question instead of a full file: the config is
  portable, the identity is not — and a committed identity is exactly the
  state/identity this repo's privacy rule forbids. Agents: ask for name
  and email (an existing `git config --global user.*` is "already
  satisfied"), explain each setting in one line, never invent values.
  Line-ending settings are OS-specific: see §2b (Windows) — on Linux/macOS
  the defaults are right.
  VERIFY: `git config --global --get user.email` → set; `git config
  --global core.pager` → delta; `git log` in any repo shows delta's
  line-numbered diff.

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
- **PWAs via firefoxpwa** (PWAsForFirefox extension + native host): mRA OS
  (os.mra.software — replaced the separate mra-agent + mRA Notes apps
  2026-09-30; its manifest ships its own icon and a "new chat" shortcut).
  Each PWA gets its own profile on purpose (session isolation). Install from
  the CLI: `firefoxpwa profile create --name "mRA OS"` →
  `firefoxpwa site install https://os.mra.software/manifest.webmanifest
  --profile <id>`; retire with `site uninstall <id> -q` + `profile remove
  <id> -q` (the `-q` skips the y/n prompt — needed from an agent shell).
  Then swap the `FFPWA-<id>.desktop` entry in
  `org.gnome.shell favorite-apps` for the dock.
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
- Extensions: the curated list with reasons is in APPS.md "Browsers".
  TRAP (2026-08-21): URL-cleaning extensions without a per-site allow list
  (ClearURLs) break Google AI Mode — the page renders, the answer request
  fails ("Something went wrong and an AI response wasn't generated").
  Diagnostic that settles it in one step: retry in a private window
  (extensions are off there); works → an extension, then toggle them on
  that page one by one. Parameter stripping now comes from uBlock Origin's
  *AdGuard URL Tracking Protection* list, which the uBO power button can
  excuse per site.
- ENVIRONMENT-SPECIFIC, NOT A SETUP ITEM (agents: never propose it): on
  the owner's machine both browsers run DNS over HTTPS (Cloudflare) as a
  workaround for a home-network condition — Wi-Fi roams on a mesh dropping
  DNS for 0.3 s. Only relevant if someone sees the same symptom ("Server
  Not Found", refresh works); diagnosis and the exact browser settings are
  in §2 "Wi-Fi roam". Owner-side detail (router settings, placement) is
  deliberately not in this repo.
- WHY firefoxpwa over a manual Chromium `--app=` window for the other PWAs:
  on Wayland, Chromium ignores `--class` → wrong dock icon unless forced to
  XWayland. firefoxpwa generates correct desktop entries natively. (A real
  Chrome PWA *install* is fine — Chrome manages its own entry, as WhatsApp
  shows — but mRA OS stays on the Firefox engine on purpose:
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
- **Synced hook paths must be portable** (PATTERN — applies to anyone who
  syncs `~/.claude` across machines; learned 2026-10-18 when the Mac
  joined): `settings.json` travels to every machine, so a hook or status
  line that calls an absolute `/home/<user>/...` path fires an error on
  every event wherever that path doesn't exist. Form:
  `f="$HOME/<path>/hook.sh"; [ -x "$f" ] || exit 0; exec "$f" <args>`
  — identical behaviour where the script exists (`exec` keeps its exit
  code, so exit 2 still blocks), a silent no-op where it doesn't.
  (`… && "$f" || true` was the first draft — it swallowed that exit code.)
  Owner's case: the hooks belong to the owner's private, unreleased
  tooling — **not a public tool; agents never offer it to non-owners**,
  they only see the pattern. FOLLOW-UP (owner): that tool's installer
  should write this form instead of an absolute path, or the conflict
  returns on every machine switch.
  VERIFY: `grep -c '"/home/' ~/.claude/settings.json` → 0.

---

## 2. OS-specific — Fedora

(Other OS layers follow as §2b, §2c… — written from real sessions, never
speculation. Each has its own `os/<os>/` scripts and `machines/` record with
freshness stamps; see HARDWARE.md / machines/README.md.)

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
- 16 GB btrfs swapfile at priority 10 under zram's 100, in its OWN
  subvolume:
  ```
  btrfs subvolume create /swap && chmod 700 /swap
  btrfs filesystem mkswapfile --size 16g /swap/swapfile
  swapon --priority 10 /swap/swapfile
  # /etc/fstab: /swap/swapfile none swap defaults,pri=10 0 0
  ```
  TRAP (cost two weeks of silent breakage, found 2026-08-20): btrfs refuses
  to snapshot a subvolume that holds an ACTIVE swapfile
  (`btrfs_util_create_snapshot_fd2 … errno 26 Text file busy`). The file
  lived at `/swapfile` inside the root subvolume from 08-06 to 08-20, so
  every snapper snapshot of `/` failed in that window — and snapper's dnf
  hook only says "Creating snapshot failed." Nested subvolumes are excluded
  from the parent's snapshot, hence `/swap` as a subvolume of its own.
  Moving it is safe while USED is ~0: create the new one, `swapon` it,
  `swapoff` + `rm` the old, fix fstab.
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
  VERIFY: `swapon --show` → two rows, zram pri 100, /swap/swapfile pri
  10, swapfile USED stays ~0 except under genuine overflow;
  `btrfs subvolume show /swap` succeeds (it is a subvolume, not a dir).
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
  blamed on scheduling but coincided with a private dev tool's main-loop leak eating a
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
  Its background download is OFF (2026-09-28):
  `gsettings set org.gnome.software download-updates false`. WHY: with it
  on, GNOME Software pre-downloads the same packages and stages an
  "offline update on next boot"; every `upall` (or any `dnf install`)
  then prints "Pending offline transaction has been invalidated" and the
  staged copy was wasted bandwidth. One channel owner: `upall`.
  VERIFY: `gsettings get org.gnome.software download-updates` → false.
- The ritual, Sunday evening, then the (already planned) weekly reboot —
  shipped as two zshrc functions (see `dotfiles/zshrc`): **`upcheck`**
  (what's pending, all four channels, one screen) and **`upall`**
  (apply everything).
- A user timer (`update-check.timer`, Sun 18:00, Persistent=true) runs
  `update-check.sh` → one desktop notification summarizing pending counts
  across all four channels; doubles as the ritual reminder. Files ship in
  this repo (`os/fedora/update-check.sh`, units in `os/fedora/assets/`),
  installed by bootstrap.
- TRAP (root cause found 2026-08-06): npm's `allowScripts` policy BLOCKS
  postinstall scripts of npm-installed CLIs — the tool then dies with
  "native binary not installed" on every invocation. Permanent fix:
  `npm config set allow-scripts=opencode-ai,protobufjs,re2 --location=user`.
  (claude-code was the original victim and had a self-heal step in `upall`;
  both retired 2026-08-17 when it moved to the native installer.)
- Fedora RELEASE upgrades (44→45) are a separate twice-yearly event: wait
  ~2-3 weeks after release, then `dnf system-upgrade`; afterwards walk the
  VERIFY lines in this manifest.
  `upall` ends with **`machine-verify`** (= `os/fedora/verify.sh`): every
  VERIFY line of this manifest as PASS/FAIL, so silent drift surfaces
  weekly instead of by accident (snapper was inert for a month and the
  swapfile blocked snapshots for two weeks before this existed, 2026-08).
  Run `sudo -E machine-verify` now and then for the root-only checks.
  WHY weekly not daily: no measurable benefit to chasing updates daily on a
  desktop; weekly + reboot picks up kernels/mesa at a humane failure rate.
  VERIFY: `systemctl --user list-timers update-check.timer` shows next Sun.

### Snapshots around every dnf transaction (snapper + dnf5 actions plugin)

- Packages: `snapper libdnf5-plugin-actions`; config `snapper -c root
  create-config /` (only `/` — `/home` is its own subvolume and is NOT
  snapshotted, which is what you want for package-level undo); hook file
  `os/fedora/assets/snapper.actions` → `/etc/dnf/libdnf5-plugins/actions.d/snapper.actions`
  (bootstrap installs it). Result: every dnf transaction on the host gets a
  `pre`/`post` pair described by the dnf command line, tagged cleanup
  `number`, pruned by `NUMBER_LIMIT=10` in `/etc/snapper/configs/root`.
  WHY this shape: the obvious package, `python3-dnf-plugin-snapper`, is a
  DNF4 plugin — Fedora 44 runs dnf5, which never loads it. It sat installed
  here from 2026-07-22 to 08-20 producing exactly zero snapshots across 90
  transactions: a silent no-op that LOOKS like protection. dnf5's own
  mechanism is the generic `actions` plugin; the hook file ports upstream's
  documented snapper example, plus `-c number` (upstream's example omits it
  and would accumulate forever).
  WHY at all: `/` is btrfs, so a pre/post pair costs ~nothing and turns a
  bad kernel/mesa/dnf-update into `snapper undochange N..M` or a file
  restore instead of a reinstall. This is package-level undo, NOT a backup
  (same disk, same LUKS volume) and NOT boot-menu rollback (Fedora has no
  grub-btrfs wiring; `/.snapshots` is a plain directory in the root
  subvolume, fine for undochange/diff).
  TRAP: see the swapfile entry above — a swapfile inside the root
  subvolume makes EVERY snapshot fail with `Text file busy`. Keep
  `/swap` a subvolume of its own.
  NOTE: `snapper-timeline.timer` may be enabled by the package; it does
  nothing because `TIMELINE_CREATE="no"` — hourly snapshots are not wanted
  (dnf pairs + the one manual baseline are the whole point).
  VERIFY: `sudo snapper list` shows `pre`/`post` rows whose Description is
  a dnf command line; after `sudo dnf reinstall -y libdnf5-plugin-actions`
  a fresh pair appears. If the dnf output ever says "Creating snapshot
  failed.", read `/var/log/snapper.log` — errno 26 means a swapfile crept
  back into `/`.

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

### TRAP (environment-specific, NOT a setup item): Wi-Fi roam → "Server Not Found"
Diagnostic knowledge only — nothing here is applied by bootstrap or checked
by verify. Read it when the symptom shows up on a multi-AP Wi-Fi network;
skip it otherwise. Router-side settings belong to the owner's network, not
to this repo.
- SYMPTOM: on a multi-AP network (owner's case: a 2-node mesh, both nodes
  on the same 5 GHz channel) pages sometimes fail to load on first try with
  Firefox's "Server Not Found"; refresh works. Measured 2026-09-27 over
  150 s windows: 674 lookups OK, every failure within 0.3 s of a roam.
- CAUSE 1 — the roams: NetworkManager hard-codes wpa_supplicant's
  `bgscan simple:30:-65:300` for any network it has seen at >1 BSSID (string
  lives in the binary; no config knob). Below -65 dBm the supplicant scans
  every 30 s, the scan takes ~7 s, and with two equal-strength APs it flips
  after every scan → a roam every **37 s, clock-regular** (2189 roams in
  one 6-day boot). Above -65 dBm the scan interval is 300 s and the
  problem vanishes — which is why an earlier "fix" (router per-client
  steering off + powersave off, 2026-09-09) only seemed to work: the desk
  signal sat above the threshold that day.
- CAUSE 2 — the failure: each roam is a full reconnect (`disconnect from AP
  … for new auth`) = 0.33 s `NO-CARRIER` on the interface. systemd-resolved
  drops the per-link scope on carrier loss and fails the in-flight query
  at once ("No appropriate name servers or networks for name found"); with
  a global `DNS=` it instead gets `ENETDOWN` from the kernel and fails just
  as fast ("Network is down"). Everything with a retry survives the gap:
  `dig` UDP/TCP, `curl --doh-url` → 0 failures across roams, ~1.1-1.6 s late.
- NOT the cause (tested): DHCP renew on roam (a static address changed
  nothing), a missing global DNS server in resolved. TRAP inside the trap:
  the global `DNS=<home router>` drop-in tried on 2026-09-27 was NOT
  harmless — resolved queries the global scope on every network, so on a
  hotspot every lookup of a non-existent name (gcloud's metadata probe,
  npm registry fallbacks) waited ~2 minutes for the unreachable home
  router. Removed 2026-10-05. Never put a LAN address in resolved's global
  `DNS=`; per-link DNS from the connection profile is the right scope.
- WORKAROUND the owner uses: browser DNS over HTTPS — Firefox Settings →
  Privacy & Security → DNS over HTTPS → **Custom**, provider Cloudflare,
  "Always warn me if secure DNS isn't available" UNCHECKED (silent native
  fallback, needed for captive portals; pref `network.trr.mode=2`); Chrome
  `chrome://settings/security` → Use secure DNS → With → Cloudflare. The
  browser's own persistent HTTPS connection queues the query through the
  gap and answers ~1 s late. Not done: system-wide DoT in resolved
  (`DNS=1.1.1.1#cloudflare-dns.com` + `DNSOverTLS=opportunistic`) — would
  cover CLI tools too, untested. Real fixes: signal above -65 dBm at the
  desk (node placement / third node), or 802.11r — see §3a for why that
  doesn't work on this chip yet.
- DIAGNOSE: `journalctl -k -b 0 | grep -c 'for new auth'` (hundreds/day =
  bgscan ping-pong; intervals via `-o short-unix`, 37 s = bgscan).

### Already-default safety layers (verify present, don't install)
- systemd-oomd active, uresourced active, fstrim.timer enabled. These are
  Fedora Workstation defaults — just confirm after install.

---

## 2b. OS-specific — Windows

Status: the first Windows session (owner, the dual-boot slice — see
`machines/thinkpad-p14s-windows.md`) has not run yet; it will fill this
layer from what is actually applied. The item below predates it because it
came from a real incident, not speculation.

### Git for Windows — line endings
- `git config --global core.autocrlf input` and `git config --global
  core.eol lf`, right after installing Git (before the first clone).
  WHY: Git for Windows' installer default is `autocrlf=true` ("checkout
  Windows-style"), which rewrites every text file to CRLF on checkout. A
  shell script checked out that way fails on Git Bash/WSL/any Linux box
  with `bad interpreter: /bin/bash^M` or `$'\r': command not found`.
  `input` = no conversion on checkout, LF normalisation on commit — files
  arrive as the repo has them and CRLF cannot leak back in even if an
  editor writes it. (`false` + `eol=lf`, the other common fix, also works
  but skips the commit-time normalisation.)
  TRAP (2026-08-21, a friend's machine running a shared repo's `.sh`): the
  global setting is per machine — it protects nobody else. Repos that mix
  platforms carry their own `.gitattributes` (`* text=auto eol=lf`,
  `*.sh text eol=lf`), which wins over any local setting; this repo has one.
  Projects that genuinely need CRLF (`.bat`/`.cmd`, legacy Windows-only
  code) declare `eol=crlf` for those paths in their `.gitattributes`.
  VERIFY: `git config --global core.autocrlf` → input; clone a repo with a
  `.sh` and `file script.sh` → "ASCII text", not "with CRLF line
  terminators".

## 2c. OS-specific — macOS

Machine: `machines/mbp14-macos.md` (MacBook Pro 14" M2 Pro, macOS Tahoe
26). Mechanics: `os/macos/{bootstrap,verify,collect,update-check}.sh`,
per-OS dotfiles in `dotfiles/macos/`.

History, because it explains the shape: the first macOS session
(2026-09-06) configured the machine and wrote this layer, but none of its
text reached GitHub (see AGENTS.md "push the port branch in the same
sitting"). The 2026-10-18 session found the machine configured and the
manifest empty, reconstructed the layer from the scripts that session had
left in `~/.local/bin` (`machine-verify`, `update-check`), re-verified every
item (36 PASS / 0 FAIL), and then completed it. Items marked
*(2026-09-06)* are reconstructions — their WHY is what the scripts'
comments recorded, nothing more.

### Already native — do not port (one line each, so the next port doesn't re-litigate)
- **Hardware video decode (§2 VA-API)**: VideoToolbox, nothing to
  install. The intent survives only in mpv's config (`hwdec=videotoolbox-copy`,
  same reason as `vaapi-copy` — software bwdif must see every frame).
- **zram + VM tuning, disk overflow swap, earlyoom (§2)**: macOS compresses
  memory and grows encrypted swap on its own — the "hard wall" failure class
  that justified all three doesn't exist here.
- **Desktop slices / uresourced (§2)**: QoS classes in the scheduler;
  nothing to tune, no measured starvation.
- **snapper around package transactions (§2)**: no brew equivalent. The
  closest thing — APFS local snapshots — comes with Time Machine, which has
  no destination yet (§3b open items).
- **GNOME theming discipline / GTK3 dark flag (§2)**: no equivalent
  problem; the system appearance reaches every app.
- **dnf `max_parallel_downloads` (§1)**: brew downloads in parallel already.
- **Line endings (§2b)**: Windows-only; macOS defaults are right.
- **mold (§1 Rust)**: mold has no Mach-O backend, and Apple's `ld_prime`
  is already multithreaded — `~/.cargo/config.toml` stays ABSENT. verify
  FAILs if mold rustflags ever appear there (they would break every build).

### Homebrew is the package manager *(2026-09-06)*
- Apple Silicon prefix `/opt/homebrew`; `brew shellenv` in `.zprofile` so
  login shells and GUI-launched apps see it. Formulae for the CLI stack,
  casks for apps (incl. `font-jetbrains-mono-nerd-font` for Ghostty), `mas`
  for the App Store. APPS.md's native-vs-Flatpak policy collapses here:
  every app is native, browsers are the vendor builds.
- zsh plugins come from `$(brew --prefix)/share/…` instead of
  `/usr/share/…` — that path is the only reason `dotfiles/macos/zshrc`
  exists as its own file.
  VERIFY: `brew --version`; `machine-verify` checks every CLI tool.

### `~/.zshenv` — PATH for non-interactive shells
- `dotfiles/macos/zshenv` prepends `~/.local/bin`, `~/.cargo/bin` and
  `/opt/homebrew/{bin,sbin}` (static paths, `typeset -U` dedupes).
  WHY: `ssh mra-mac <cmd>`, agent tool calls and some launchd jobs run zsh
  non-interactively, and those read ONLY `~/.zshenv` — without it brew,
  node, cargo and `~/.local/bin` (claude, agy) are invisible to remote
  commands. On a machine whose main job is being reached over SSH, that is
  the difference between `ssh mra-mac claude …` working or not. Static
  rather than `eval "$(brew shellenv)"` so no subshell pays for a brew call.
  (`.zprofile`/`.zshrc` still prepend too: `/etc/zprofile`'s `path_helper`
  reorders PATH in login shells after `.zshenv` ran.)
  VERIFY: `env -i HOME=$HOME zsh -c 'command -v brew node claude'` → three paths.

### Node + agent CLIs
- `node@24` from brew, `brew link --force` — the Active LTS line (22 is
  maintenance-only since 2025-10; the Mac started on node@22 to mirror the
  Fedora inventory's `nodejs22` and moved to 24 the same day; Fedora
  followed the same day — APPS.md "Dev runtimes": one LTS line everywhere).
  nvm from its upstream script with `PROFILE=/dev/null` (the zshrc already
  sources it) and `nvm alias default system`, so nvm never shadows the brew
  node; pnpm from brew. `npm -g` lands under `/opt/homebrew` — visible to
  non-interactive shells through `.zshenv`, unlike an nvm-managed global.
- codex + opencode-ai via `npm -g`; agy via its official installer
  (`curl -fsSL https://antigravity.google/cli/install.sh | bash` —
  checksum-verified, `~/.local/bin/agy`, self-updates).
  TRAP: agy's installer APPENDS `export PATH="$HOME/.local/bin:$PATH"` to
  BOTH `.zshrc` and `.zprofile` — redundant here; snapshot both files
  before and restore them after (bootstrap does).
- The Fedora npm `allow-scripts` TRAP (§2 "Update cadence") applies here
  too, with a version boundary worth knowing: the key exists only in
  npm 11+ (node 24). Under node@22's npm 10 the same command fails with
  "`allow-scripts` is not a valid npm option" and postinstalls just run —
  so the setting is needed exactly when the Node line ships npm 11.
  `npm config set allow-scripts=opencode-ai,protobufjs,re2 --location=user`.
  VERIFY: `node --version` → v24.*; `npm config get allow-scripts` lists
  opencode-ai; `codex --version`, `opencode --version`, `agy --version` answer.

### Containers — podman machine, `docker` = alias *(2026-09-06 + 2026-10-18)*
- podman runs in an `applehv` VM (`podman machine`); `DOCKER_HOST` points at
  its API socket under `$(getconf DARWIN_USER_TEMP_DIR)` — resolves the
  random `/var/folders` path without `sudo podman-mac-helper install`.
- `alias docker=podman` replaces Fedora's `podman-docker` shim. Picked over
  `brew install docker` (the real CLI against the socket): zero extra
  package. LIMIT: an alias doesn't exist for non-interactive callers — if a
  tool ever shells out to `docker` by name, switch to the real CLI.
  VERIFY: `podman machine list` → running; the `DOCKER_HOST` socket exists.

### Static hostname — same Chromium singleton-lock trap as §2 *(2026-09-06)*
- `HostName`, `LocalHostName`, `ComputerName` = `mra-mac` (`sudo scutil
  --set …` for each). With `HostName` unset, macOS derives the name from
  DHCP/Bonjour and it can change under the apps — the §2 failure mode
  verbatim.
  TRAP (2026-10-18): the 2026-09-06 session set only `HostName`.
  `LocalHostName` — the Bonjour name behind `<name>.local` — stayed
  `mRAs-MacBook-Pro`, so `ssh mra@mra-mac.local` from the ThinkPad didn't
  resolve and the first key-login test went nowhere. The three are
  separate settings; set and check all three.
  VERIFY: all three `scutil --get` → mra-mac; `dscacheutil -q host -a name
  mra-mac.local` answers.

### Touch ID for sudo *(2026-09-06)*
- `/etc/pam.d/sudo_local` from `sudo_local.template` with the `pam_tid.so`
  line uncommented — `sudo_local` survives OS updates, edits to
  `/etc/pam.d/sudo` do not. Same quirk as the ThinkPad fingerprint: an
  agent shell has no TTY, so sudo can't prompt there — hand the user a
  `! sudo …` line instead (`mas install` needs sudo since mas 7, too).
  VERIFY: `grep pam_tid /etc/pam.d/sudo_local` → uncommented.

### IINA — the mpv front-end owns video and streams *(2026-09-06)*
- IINA (mpv-based, native UI) is the default for `m3u8 mp4 mkv webm`
  (`duti -s com.colliderli.iina <ext> all`) — the Fedora trap ".m3u8 falls
  to the music app" reproduces on macOS verbatim (Music.app).
  `defaults write com.colliderli.iina useUserDefinedConfDir -bool true`
  makes IINA read `~/.config/mpv`, so one `dotfiles/macos/mpv.conf` drives
  both IINA and the `mpv` CLI: same deinterlace reasoning as §1, with
  `hwdec=videotoolbox-copy` and no Wayland context line.
  VERIFY: `duti -x m3u8` → IINA; in the `mpv` CLI Shift+i shows videotoolbox-copy.

### Update cadence — four channels, one ritual
- Channels: brew (formulae + casks `--greedy`), `softwareupdate` (macOS and
  firmware ride the same update), `npm -g`, `mas`. `upcheck`/`upall` live
  in `dotfiles/macos/zshrc`; `sudo softwareupdate -i -a -R` stays a line
  upall PRINTS (sudo + reboot — a human decision).
- Notifier: LaunchAgent `com.machine-setup.update-check` (Sun 18:00;
  `StartCalendarInterval` fires a missed run on wake — launchd's
  `Persistent=true`) → `os/macos/update-check.sh`. *(2026-09-06)*
  TRAP (found 2026-10-18): the first version sent every error to
  `/dev/null` and counted lines with `grep -c`, so a FAILED check read as
  "0". Five Sundays in a row said "Everything up to date" while 59 updates
  — including the macOS 26.7.1 security release — were pending. Fixed: it
  waits up to 5 min for the network after a wake, each channel records its
  own failure, and the notification says "check FAILED: brew macOS …"
  instead of a number. Rule for any notifier: a failed probe must never be
  indistinguishable from a clean result.
- macOS's own automatic install stays at the platform default on a normal
  Mac. On the always-on server it is turned off — a ROLE decision, see §3b
  "Updates on the server".
- Major macOS releases follow the Fedora release rule: wait for x.1 /
  2-3 weeks, and have a backup first. 2026-10-18: macOS 27.0.1 was out; the
  Mac stayed on 26.x — Xcode 27.1 only needs 26.6, so nothing forced it.
  VERIFY: `launchctl list | grep update-check`; the log line has no `FAILED=`.

### Keyboard — Linux shortcut muscle memory on a Mac (Karabiner-Elements)
- The macOS split: Cmd = app shortcuts, Ctrl = terminal control codes. It
  is cleaner than Linux in a terminal (no Ctrl+Shift+C), but every app
  shortcut moves to the thumb key. Options weighed 2026-10-18: (a) get used
  to Cmd, (b) Karabiner rules scoped away from terminals, (c) swap
  Ctrl↔Cmd in Settings → Keyboard → Modifier Keys — REJECTED (§4: it moves
  the terminal's Ctrl+C to the thumb and every Cmd shortcut to the corner).
  Chose (b) for the desk; (a) is what remote use gets anyway (VNC sends the
  Linux Super key as Cmd, and Karabiner only touches physical keyboards).
- `brew install --cask karabiner-elements` (pkg — needs sudo, so the user
  runs it), open it once, approve Driver Extensions + Input Monitoring
  (`karabiner_grabber`, `karabiner_observer`), keyboard type ANSI. Rules
  live in `dotfiles/macos/karabiner-pc-style.json` (a complex-modifications
  asset): merged into the selected profile of `~/.config/karabiner/karabiner.json`
  with jq, and copied to `assets/complex_modifications/` so the UI shows them.
  - Ctrl+A/C/F/L/N/O/P/R/S/T/V/W/X/Z (+Shift) → Cmd; Ctrl+Y → Cmd+Shift+Z.
    Ctrl+Q left out on purpose — a slip would quit the app.
  - Home/End → line start/end, Ctrl+Home/End → document start/end
    (+Shift selects); Ctrl+←/→ → word jump; Ctrl+Backspace/Delete → delete
    word. (Ctrl+←/→ were Mission Control's "switch Space" keys — outside
    terminals the rule wins.)
  - EXCLUDED apps get raw Ctrl: Ghostty, Terminal, iTerm2 (SIGINT, history
    search, delete-word…) and Screen Sharing / UTM / Windows App / Parallels
    (the remote OS decides).
  - Terminals get the LINUX TERMINAL habit instead: Ctrl+Shift+C/V → copy/
    paste, Ctrl+Shift+T/W → new/close tab (Ghostty on Fedora uses exactly
    these). Added after the first test (2026-10-18): with terminals simply
    excluded, Ctrl+C correctly interrupted but there was no Linux-style way
    to copy — "works like before" read as "not working".
- VS Code is NOT excluded (editor shortcuts are the point), but Karabiner
  can't tell its editor from its integrated terminal — there Ctrl+C would
  arrive as Cmd+C. `dotfiles/macos/vscode-keybindings.json` → VS Code's
  `keybindings.json` hands the shell its control codes back while the
  terminal has focus: Cmd+C (no selection) → `^C`, Cmd+A/L/R/W/Z → `^A ^L
  ^R ^W ^Z`. Settings Sync keeps keybindings per platform, so this never
  reaches Fedora's VS Code.
- Input sources: ABC (US) default, Turkish Q-PC second — matches the
  keyboard's printed (US) layout.
  VERIFY: `machine-verify` counts the selected profile's "PC-style" rules → 4
  (rules of your own don't count); in TextEdit Ctrl+C/V copy-paste; in Ghostty Ctrl+C interrupts `sleep 30`
  and Ctrl+Shift+C/V copy-paste.

### Claude Code on macOS — attaching `~/.claude` (owner)
- Native installer as on Fedora. `~/.claude` already existed (first launch
  creates it), so the private sync repo was attached IN PLACE: clone to a
  scratch dir, move its `.git` into `~/.claude`, `git checkout -- .` (the
  repo wins; the local `settings.json` was a subset). Sessions/history stay
  untouched — the allowlist `.gitignore` never sees them.
- Plugins: `extraKnownMarketplaces` is NOT registered automatically on a
  fresh machine — `claude plugin install x@mralabs` fails with "not found
  in marketplace". Register each first (`claude plugin marketplace add
  <owner/repo>`), then run MIGRATION.md's install loop.
  TRAP: `marketplace add` REWRITES `settings.json` — it reordered keys and
  DROPPED `autoUpdate: true` from all seven marketplaces. Afterwards
  `git -C ~/.claude checkout -- settings.json`; the registrations live in
  `plugins/known_marketplaces.json` and survive the restore.
- Sync: `dot-claude-sync` linked into `~/.local/bin`, run by hand before
  leaving the Mac — no launchd timer (two machines auto-pushing only
  multiplies rejected pushes; pulling stays deliberate per MIGRATION.md).
- Project memory is keyed by absolute path (`-home-mra-Projects-X` on
  Fedora, `-Users-mra-Projects-X` here), so without help each machine grows
  its own diverging memory for the same project. Fix: clone projects at the
  SAME path below `$HOME` (`~/Projects/<Fedora layout>`), then run
  `link-project-memory` (in the synced `~/.claude/bin`, symmetric,
  idempotent): it symlinks this machine's `<slug>/memory` to the other
  machine's, so both share one copy. The links never enter the repo — the
  allowlist's `!/projects/*/memory/` matches directories only and git sees
  a symlink as a file (tested). Do NOT run MIGRATION.md's re-addressing
  while both machines are live — it MOVES the directories and Fedora loses
  them. TRAP from writing the script: slugs start with `-`, so `mkdir
  "$slug"` parses as an option — pass `./$slug`; the first draft also
  printed "25 linked" after 25 failures (a silent-failure twin of the
  update-check one).
  VERIFY: `git -C ~/.claude remote get-url origin` → dot-claude-config;
  `grep -c '"/home/' ~/.claude/settings.json` → 0 (§1 portable hooks);
  `link-project-memory --check` → "0 unlinked, 0 conflict(s)".

## 3a. Hardware-specific — ThinkPad P14s Gen6 AMD (`thinkpad-p14s`)

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
- **MT7925 Bluetooth dead after a Windows visit (TRAP, 2026-08-31)**: the
  Wi-Fi/BT combo chip's Bluetooth half is a USB function (`0e8d:e025`);
  on three consecutive warm boots its firmware handshake timed out —
  `Bluetooth: hci0: Execution of wmt command timed out` /
  `Failed to send wmt func ctrl (-110)` — so `hci0` existed but never
  registered (`bluetoothctl list` empty, GNOME toggle inert, rfkill clean,
  bluetoothd fine). Warm reboots don't cut power to the chip, so the bad
  state survived them. First seen right after a Windows session (the same
  visit also charged the battery to 100% past the 80% cap); the boots after
  the earlier Windows visits were clean, so the trigger is likely Windows'
  hybrid shutdown (Fast Startup) or a Windows BT driver update leaving the
  chip half-initialised — keep Fast Startup OFF on the Windows side.
  FIX: a **full power-off** (not a reboot) — after it the log shows
  `hci0: Device setup in … usecs` with no wmt line, and the controller
  registers first try. Reloading the driver
  (`sudo modprobe -r btusb btmtk && sudo modprobe btusb`) is only a
  band-aid: it brought Bluetooth up on 2026-08-31 but the controller stayed
  degraded — the second reload still logged a wmt timeout and the mouse's
  link dropped ~3x more often than normal (11 reconnects in 28 h vs 1-4 a
  day) until the cold boot the next day. Use the reload to get through the
  day, then power off.
  VERIFY: `journalctl -k -b | grep -E 'wmt|Device setup'` → only the
  "Device setup" line; `bluetoothctl list` shows a controller; MX Master
  reconnects (`journalctl -b | grep -c 'input: Logitech MX Master'`) stay
  in the 1-4/day band.
- **MT7925 Wi-Fi: 802.11r fast roaming is negotiated but fails** (2026-09-27,
  kernel 7.2.5, firmware 20260813): with the mesh advertising `FT/PSK`, the
  supplicant runs the FT auth and then logs `FT: Failed to set PTK to the
  driver` / `nl80211: kernel reports: key not allowed` and falls back to a
  full reconnect — so 802.11r does NOT shorten the carrier drop described in
  §2 "Wi-Fi roam". A mac80211 patch deferring the FT key install is in
  flight upstream (Sep 2026). Leave fast roaming ON at the router; after
  kernel updates check `journalctl -b -u wpa_supplicant | grep -c 'FT: Failed'`
  (the line comes from wpa_supplicant, NOT the kernel — `journalctl -k` always
  reads 0 and once produced a false "fixed" verdict, 2026-10-12) against
  `journalctl -k -b | grep -c 'for new auth'`. When FT failures read 0 with
  roams still happening, roams have become carrier-preserving and the DoH
  workaround can be reconsidered. Still failing on every roam at kernel 7.2.9
  (2026-10-13: 59 roams, 59 failures).
- **BIOS updates via fwupd/LVFS FAIL on this disk layout (TRAP, 2026-09-28)**:
  the ESP is the 100 MB one Windows created at the factory
  (`nvme0n1p1`, ~45 MB free); a UEFI capsule update needs ~140 MB there —
  `fwupdmgr update` says "/boot/efi does not have sufficient space" and
  leaves the device in `Update State: Failed`, and `upall` re-offers it every
  week. Enlarging the ESP means moving the Microsoft reserved + Windows
  partitions right behind it — not worth it. Apply BIOS updates from the
  Windows side instead (Lenovo Vantage / System Update, which flashes
  without the ESP) or Lenovo's bootable BIOS-update USB; answer `n` to the
  fwupd prompt meanwhile. Firmware for other devices (fingerprint, dock,
  NVMe…) still goes through fwupd fine — only the system-firmware capsule
  hits the limit. Read the WHOLE chain before skipping one: 0.1.22 alone
  only touches a touch-panel list, but it is cumulative and the 0.1.21 it
  carries is Urgency High with a security fix (2026-10-19: still on 0.1.19,
  apply from Windows). Pending Secure Boot dbx updates ride along there too —
  Windows Update applies them and keeps its own boot manager current first.
- **Fingerprint reader**: enrolled for sudo. Quirk: sudo inside embedded
  terminals/AI sessions may lack a TTY for password fallback — run sudo
  commands in a real terminal window.
- **NPU (XDNA2)**: Lemonade stack serves local models on localhost:13305.
  Good for small/fast tasks; RAM is the model-size ceiling, not TOPS.
- Thermal envelope reference (healthy): idle ~45-52°C, fan off or ~2400 RPM;
  full-core rustc ~82°C / 4990 RPM is NORMAL (throttle at 95+). Fan hysteresis:
  spins up fast, ramps down slowly — a loud fan minutes after load ended is
  soak, not a problem.

## 3b. Hardware-specific — MacBook Pro 14" M2 Pro (`mbp14`)

**Nothing here auto-ports.** This machine has a ROLE as much as hardware:
an always-on home server that is also a desk machine (own desk, monitor,
Magic Keyboard + Magic Mouse). Remote jobs: SSH and Screen Sharing from the
ThinkPad (usually on the same home LAN), iOS-simulator testing, overflow
compute/RAM for agent sessions, Home Assistant OS in a UTM VM (the
house's devices; "UTM VM at login" below), and a self-hosted GitHub
Actions runner for headless macOS builds ("GitHub Actions runner" below). Items below are tagged
*[role]* where they follow from being a server rather than from the
hardware — if the Mac ever goes back to being a plain laptop, those are the
ones to revisit.

**[role] items are the OWNER's choice for THIS machine — never a default.**
Agents don't offer them to non-owners or on the owner's other Macs unless
the user describes the same role (always-on, reached remotely). Mechanics
follow the same line: `os/macos/bootstrap.sh` applies them only with
`--server`, which also writes `server` into `~/.config/machine-setup/roles`;
`os/macos/verify.sh` checks them only where that marker exists, so a plain
Mac never FAILs a server check.

### Power — always on *(2026-09-06)*
- *[role]* `sudo pmset -c sleep 0 womp 1`: never sleeps on AC, wakes for
  network; the DISPLAY still sleeps (10 min) and the desk use is unaffected.
  `autorestart` (power-loss restart) is an Intel-era SMC knob — Apple
  Silicon doesn't expose it (`pmset -g cap`), and the battery rides through
  short outages anyway.
- Lid: with no external display attached, a closed lid still sleeps the
  machine regardless of `sleep 0` — keep the lid open when the monitor is
  unplugged.
- Charge limit 80% (Settings → Battery → Charging) — the battery lives on
  AC. No CLI read-back; verify by eye: on AC at 80% `pmset -g batt` says
  "not charging".
  VERIFY: `pmset -g custom` AC block → `sleep 0`, `womp 1`.

### Remote access — LAN first, Tailscale when away
- *[role]* **Remote Login (SSH) + Screen Sharing** on via Settings →
  General → Sharing (the CLI route, `systemsetup -setremotelogin`, wants
  Full Disk Access for the terminal — the toggle is one click). From the
  ThinkPad on the same LAN: `ssh mra@mra-mac.local`; Screen Sharing from
  Linux = any VNC client to `mra-mac.local:5900` with the macOS account.
  (Remote keyboard: the Linux Super key arrives as Cmd — Super+C copies.
  Karabiner rules (§2c) only touch the physical keyboard, not VNC input.)
- *[role]* **SSH: keys only.** The ThinkPad's public key came from GitHub
  instead of a copy-paste between machines: `gh auth refresh -s
  read:public_key`, then `gh api user/keys` shows each key's TITLE
  (`curl github.com/<user>.keys` lists keys without titles) — only the key
  titled `mra-fedora` went into `~/.ssh/authorized_keys` (700/600 perms).
  Another, older key on the account was deliberately NOT authorized. Order matters: log in from the ThinkPad with the key FIRST,
  then `/etc/ssh/sshd_config.d/010-machine-setup.conf` =
  `PasswordAuthentication no` + `KbdInteractiveAuthentication no`, checked
  with `sudo sshd -t`. `010-` because sshd keeps the FIRST value it reads
  and includes `sshd_config.d/*` alphabetically — it must sort before
  macOS's own `100-macos.conf`. No restart: launchd starts sshd per
  connection. Desk login and Screen Sharing passwords are unaffected.
  Rollback: delete the file.
  VERIFY: `ssh -o PreferredAuthentications=password mra@mra-mac.local` from
  another machine → "Permission denied (publickey)".
- *[role]* **Tailscale as a system daemon, not the app**: `brew install
  tailscale` + `sudo brew services start tailscale` + `tailscale up
  --hostname=mra-mac`. WHY: the formula's `tailscaled` is a LaunchDaemon —
  up before anyone logs in. The app variant (`tailscale-app` cask) is a
  login item, so after a reboot the box would be unreachable from outside
  until someone logs in at the desk. Cost: no menu-bar icon; `tailscale`
  CLI manages it.
- *[role]* **FileVault + unattended reboots**: FileVault stays on; after a
  reboot the Mac waits at the pre-boot unlock screen with no network
  services. macOS 26 unlocks FileVault over SSH when Remote Login is on —
  TESTED 2026-10-18 on the 26.7.1 update restart: `ssh mra@mra-mac.local`
  from the ThinkPad while the Mac sat at the unlock screen unlocked it.
  LAN only (Tailscale isn't up pre-boot). Expect it to ask for the
  account password rather than use the key: `~/.ssh/authorized_keys` and
  the keys-only drop-in live on the encrypted volume (not recorded in the
  test — note it on the next reboot). Fallback for planned restarts when away: `sudo fdesetup
  authrestart` (one restart that skips the unlock prompt).
- *[role]* **Tailscale field test** (2026-10-18): SSH worked from the
  ThinkPad over the LAN, over Tailscale on the LAN, and over Tailscale with
  the ThinkPad on a phone hotspot (outside the home network).
- *[role]* **podman machine at login**: after the 26.7.1 restart the VM
  stayed stopped (`DOCKER_HOST` had no socket). LaunchAgent
  `com.machine-setup.podman-machine` (`os/macos/assets/`) runs `podman
  machine start` once per login, with `AbandonProcessGroup=true`.
  TRAP: without that key launchd kills the job's whole process group when
  `podman machine start` exits — the VM included. The first version logged
  "started successfully" and left nothing running. Cost: the VM holds ~2 GB RAM + 5 vCPU
  shares all the time — fine on 16 GB; containers come back with the box.
- *[role]* **UTM VM at login** *(2026-10-18)*: Home Assistant OS
  (`haos_generic-aarch64`, QEMU backend with the hypervisor — virtualized,
  not emulated; UEFI, VirtIO disk, 4 GB RAM, 2 cores, no display) bridged to
  `en0`. LaunchAgent `com.machine-setup.utm-vm` (`os/macos/assets/`) runs
  `utmctl start "Home Assistant"` once per login; utmctl launches UTM
  itself. A user app, so it needs the console session: an update restart
  logs in by itself, an unplanned one waits at FileVault (and the heartbeat
  alarms). TESTED 2026-10-18: `sudo fdesetup authrestart` skips the
  FileVault screen but stops at the LOGIN WINDOW (no session, no VM until
  someone logs in — desk or Screen Sharing); after the login the VM was
  serving in ~20 s. Lock screen and display sleep keep the session, so
  only a restart needs a login. Owner's choice: keep UTM and log in once
  per restart, rather than a root QEMU LaunchDaemon that needs no login.
  Cost: 4 GB RAM next to podman's 2 GB.
  TRAPS (measured): (1) a cask-installed UTM keeps its quarantine flag until
  it is opened ONCE on the screen (Gatekeeper "Open"); until then every
  AppleEvent to it — `utmctl`, `osascript` over SSH — hangs and ends in
  "AppleEvent timed out (-1712)". (2) `utmctl` from the LaunchAgent and
  `osascript` from an SSH session each ask once on the screen for
  Automation permission (Privacy & Security → Automation). After those, the
  VM can be created (`make new virtual machine` AppleScript), changed and
  started entirely over SSH. (3) Bridged to Wi-Fi, macOS rewrites the
  guest's MAC to the Mac's own on the air: the LAN sees both addresses with
  one MAC, so a router DHCP reservation cannot single out the VM — the
  guest takes a static address inside it instead.
  The VM's own setup (address, backups, integrations) lives with its owner's
  runbook, not here.
- *[role]* **tmux** for every long remote session (Claude Code included):
  an SSH drop kills the shell, not the tmux session — `tmux new -As main`.
  VERIFY: `nc -z localhost 22` and `:5900` succeed; `tailscale status`
  lists mra-mac online.

### Updates on the server
- *[role]* macOS automatic INSTALL off
  (`sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate
  AutomaticallyInstallMacOSUpdates -bool false`); Security Responses /
  XProtect (`CriticalUpdateInstall`, `ConfigDataInstall`) stay automatic.
  WHY: an unannounced restart is an outage on an always-on box (and lands
  at the FileVault unlock screen), and one channel should own updates —
  `upall`, the same decision as GNOME Software's `download-updates=false`
  in §2. Rollback: the same command with `true`.
  VERIFY: `AutomaticallyInstallMacOSUpdates` → 0, `CriticalUpdateInstall` → 1.

### iOS app testing — Xcode + Simulator
- *[role]* Xcode from the App Store (`sudo mas install 497799835` — mas 7
  needs sudo, so the user runs it, or the App Store button), then
  `sudo xcode-select -s /Applications/Xcode.app && sudo xcodebuild
  -license accept && sudo xcodebuild -runFirstLaunch` (one line, silent
  until "Install Succeeded"). Command Line Tools alone have no simulator.
  Xcode 27.1 (2026-10-15) needs macOS 26.6 — no OS upgrade required.
  TRAP: Xcode 27.1's first launch ALREADY brought the matching iOS 27.1
  simulator runtime; the `xcodebuild -downloadPlatform iOS` run afterwards
  fetched iOS 27.0 on top (+8 GB). Check `xcrun simctl list runtimes`
  first and download only when it lists no iOS runtime.
- Rust targets `aarch64-apple-ios` + `aarch64-apple-ios-sim` (cheap; Tauri
  mobile / Rust-on-iOS testing).
  VERIFY: `xcode-select -p` → `/Applications/Xcode.app/…`; `xcrun simctl
  list runtimes` shows an iOS runtime.

### Peripherals at this desk
- **Magic Mouse secondary click**: off by default (`MouseButtonMode =
  OneButton` — "right-click doesn't work"). `defaults write
  com.apple.AppleMultitouchMouse MouseButtonMode -string TwoButton` (+ the
  same key in `com.apple.driver.AppleBluetoothMultitouch.mouse`);
  reconnect the mouse if it doesn't take at once.
- **Scroll direction**: "natural" OFF — kept, it matches the Fedora mouse
  habit. On macOS ONE switch (`com.apple.swipescrolldirection`) covers
  mouse and trackpad; there is no per-device setting without extra tools.
- No Logi Options+ (the MX Master stays at the ThinkPad desk).
  VERIFY: `defaults read com.apple.AppleMultitouchMouse MouseButtonMode` → TwoButton.

### Health — heartbeat, memory, disk (the box can't report its own death)
- *[role]* `os/macos/health-check.sh` every 5 min as a LaunchDaemon with
  `UserName` (runs with nobody logged in at the desk, from the moment
  FileVault is unlocked). It pings a dead-man's-switch receiver — an **Uptime Kuma Push
  monitor** (URL contains `/api/push/` → `status=up|down&msg=`) or a
  **healthchecks.io** check (POST to URL / `URL/fail`); period 5 min, ~10 min
  grace: when the pings STOP — machine off, frozen, offline, waiting
  at the FileVault screen — the service alerts the phone. Ping URL in
  `~/.config/machine-setup/healthcheck-url` (600; a token, never the repo).
  WHY an outside service: everything on the Mac — notifications included —
  dies with the Mac, and at a headless box nobody sees a desktop toast. A
  plain push service (ntfy) is not enough on its own: it can only speak
  while the Mac is alive; the receiver must notice SILENCE. It must also be
  reachable from the Mac (a public `/api/push/` path or the tailnet).
  **mra-mac's receiver (2026-10-18):** the Uptime Kuma on mra-server, Push
  monitor `mra-mac` (300 s, 1 retry, alarms to the phone by ntfy and mRA OS),
  through its public push path — not the tailnet, so the Mac's state is
  known even when the box ↔ home link is down. Monitor, URL form, alarm
  tests and what to do on an alarm: mra-server `docs/49-mra-mac.md` §3
  (private repo).
- Same run, trend + alerts: one line per run in
  `~/Library/Logs/machine-setup-health.log` (memory pressure level, free %,
  swap, disk free, Wi-Fi channel/signal, top-3 memory users; rotates at
  5 MB). Memory pressure at warn+ (`kern.memorystatus_vm_pressure_level` ≥ 2)
  for 3 runs in a row, disk free < 30 GB, or a FAILED weekly maintenance →
  the ping goes to `/fail` with the reason as body, so the alert says WHY.
  Judge memory by PRESSURE, never by "used" or swap size — the §2 zram rule
  holds here too. `DISK_FLOOR_GB=1000 health-check` exercises the alert path.
  VERIFY: `machine-verify` → daemon installed, URL present, last log line
  < 15 min old with `ping=ok`.

### Disk maintenance — weekly
- *[role]* `os/macos/maintenance.sh`, Sunday 04:00, same daemon pattern:
  `simctl delete unavailable`, Xcode DerivedData folders untouched 30+ days,
  `brew cleanup -s --prune=30`, `podman image prune -f` (DANGLING images
  only — never containers, volumes or tagged images: those may hold
  someone's data). One line per run with GB freed; a failed step
  writes `FAILED=<step>`, which the health check turns into an alert.
  VERIFY: `tail -1 ~/Library/Logs/machine-setup-maintenance.log` → no `FAILED=`.

### GitHub Actions runner *(2026-10-19)*
- *[role]* A self-hosted runner (`actions/runner`, auto-update on) runs
  headless macOS CI and release jobs here instead of on hosted macOS runners
  (10× minutes for private repos). It runs as its own user, **`ghrunner`**:
  not an admin, no sudo, no SecureToken (cannot unlock FileVault), a random
  password nobody keeps, no SSH key, hidden from the login window. The owner's
  home goes to `700`: macOS creates homes `750` with group `staff`, and every
  new user is in `staff`, so a job could otherwise read `~/Projects`.
- *[role]* LaunchDaemon `com.machine-setup.github-runner`
  (`os/macos/assets/`, `UserName`, `SessionCreate`, `KeepAlive` on a failed
  exit only — `run.sh` loops over updates itself and exits 0 on a terminal
  error, which must stop and alarm, not restart every 10 s): up from the
  moment FileVault is unlocked, nobody logged in. NOT GitHub's `svc.sh` — on
  macOS it installs a LaunchAgent, which runs only during a login. The plist
  sets `HOME`, `PATH` (rustup in `~/.cargo/bin`, Homebrew) and `LANG`, which
  launchd does not; `config.sh` must run with the same `PATH` (it records it
  in `.path`). `SessionCreate` gives jobs a security session, which
  `security`/`codesign` need for a temporary keychain outside a login.
- *[role]* Job-completed hook `os/macos/github-runner-job-completed.sh`
  (`ACTIONS_RUNNER_HOOK_JOB_COMPLETED`), installed as a root-owned copy in
  `/usr/local/libexec/machine-setup/` (the runner user cannot read the
  owner's home): deletes the job's checkout, every non-login keychain, any
  `.p12` (home and the user's `/tmp` files; launchd gives no `TMPDIR`), and
  resets the default keychain. The tool cache stays.
- *[role]* The health check (§3b "Health", above) alarms `github runner not running` when
  the daemon's plist is installed and no `Runner.Listener` process exists in
  two runs in a row (a self-update restart can fall in one sample).
- TRAP: on macOS every user can read every process's argv (`ps`). With a
  second user on the machine, no token on a command line: the health check
  gives curl its ping URL on stdin (`-K -`).
- Not automated in `bootstrap.sh`: a one-time, interactive sudo setup with a
  single-use registration token. This Mac's steps, the org it serves and its
  security rules: mra-server `docs/52-mac-runner.md` (private repo).
  VERIFY: `sudo launchctl print system/com.machine-setup.github-runner` →
  `state = running`; `sysadminctl -secureTokenStatus ghrunner` → DISABLED;
  `stat -f %Sp ~` → `drwx------`.

### Decided for now
- **No UPS** (2026-10-18, accepted): the battery covers short outages; a
  long one shuts the Mac down, and it stays at the FileVault screen —
  unlockable from the LAN only — until someone home unlocks it. The
  heartbeat makes that state visible instead of silent.
- **No static IP for the Mac**: SSH/Screen Sharing find the Mac by NAME
  (`mra-mac.local`, Tailscale `mra-mac`), so an address change breaks
  nothing. The devices in the house talk to the Home Assistant VM, not to
  the Mac, and the VM keeps a static address of its own (trap (3) above).
- **Wi-Fi, not Ethernet**: no cable run to this desk. Measured 2026-10-18
  over 10 min (484 samples, 1 s apart): 2 single ping losses to the router
  (0.4 %), 0 DNS failures, channel 40 / 5 GHz throughout (no roam), signal
  -53…-61 dBm — clear of the -65 dBm bgscan threshold behind the Fedora
  roam trap (§2). The health log records channel + signal every 5 min, so
  a roaming or fading link shows up there long-term.
  Reference test: `ping -c1 -t1 <router>` + `host github.com` once a second.

### Open items (decided to revisit, not forgotten)
- **Time Machine**: no destination. Wanted before the macOS 27 upgrade at
  the latest; waits for an external disk. (Home Assistant's data lives in
  the VM and backs itself up off the Mac, so it does not wait on this.)
- **macOS 27**: wait for 27.1 (§2c "Update cadence").

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
- **macOS application firewall (mbp14)**: left off (2026-10-18). The Mac
  sits behind the home router's NAT and its whole job is accepting SSH /
  Screen Sharing — the app firewall would only add allow-exceptions for
  exactly those, protecting nothing else that is listening. Revisit if it
  ever joins an untrusted network.
- **Swapping Ctrl↔Cmd in System Settings (macOS)**: rejected for Linux
  muscle memory — it moves the terminal's Ctrl+C onto the thumb key and
  every macOS Cmd shortcut into the corner; both worlds break. Karabiner
  rules scoped away from terminals do the job instead (§2c).
- **Browser extensions on the Mac, by setup**: not installed by the agent —
  Firefox Sync / the Google account bring them back on sign-in (APPS.md
  stays the decision record).
- **Steam, Logi Options+, PWAs on the Mac**: not wanted there (no gaming on
  the server; Apple peripherals at that desk; PWAs set up by hand if ever
  needed).
