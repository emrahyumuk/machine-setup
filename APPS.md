# Applications & Tools — curated

What is installed **on purpose** and why. The raw generated lists live in
`inventory/<machine-os>/` (appendix; includes noise like libs and preinstalled defaults —
this file is the intent).

## Packaging policy — native (rpm) vs Flatpak

The Source column below is not accidental. Decision rule:

- **Native (rpm/COPR/vendor repo)** for anything that must integrate with the
  host: browsers, terminals, editors, dev tools and CLI tools.
- **Flatpak** for leaf/consumer apps where sandboxing is a feature and host
  integration needs are low: chat, music, GUI utilities.

Load-bearing consequences (do not "migrate to Flatpak" casually):

- **Browsers MUST stay native.** The VA-API hardware-decode fix
  (SETUP.md §2, `mesa-va-drivers-freeworld`) is a HOST mesa package — a
  Flatpak browser ships its own runtime mesa and never sees it; the 83→51°C
  win silently dies. (Flatpak browsers need their own codec extensions
  instead.) firefoxpwa's native-messaging host also assumes native Firefox.
- **Terminals/dev tools native**: Ghostty, VS Code, CLI stack need the host
  shell, toolchains and project files without portal friction.
- **Podman Desktop works fine as Flatpak** (talks to the host podman
  socket; the sandbox doesn't get in the way).

## Desktop applications

| App | Source | Why / notes |
|-----|--------|-------------|
| Firefox | Fedora | Main browser (full uBlock Origin lives here — see "Browsers" below). Separate "Music" profile launched as its own app; default profile pinned via alias (profile group drifts to last-used otherwise — see `dotfiles/zshrc`). |
| firefoxpwa (PWAsForFirefox) | rpm + extension | PWAs as real apps: mRA OS (os.mra.software; replaced mra-agent + mRA Notes 2026-09-30). (WhatsApp moved to a Chrome PWA 2026-08-18 — messages intermittently stalled in the Firefox PWA; WhatsApp Web treats Chromium as first-class.) See SETUP.md §1 for icon + link-handling config. |
| Google Chrome | Google repo | Tool browser — Claude-in-Chrome, WebHID (Qudelix 5K `--app` window, XWayland — see SETUP.md hardware notes), WhatsApp PWA. Roles + extensions in "Browsers" below. |
| Ghostty | COPR | Terminal. Config in `dotfiles/ghostty.config` (Catppuccin Mocha, JetBrainsMono Nerd Font). |
| VS Code (`code`) | Microsoft repo | Editor. |
| Neovim | Fedora | `vim`/`EDITOR` alias target. |
| Thunderbird | Fedora | Mail. |
| mpv | RPM Fusion | THE video player (there was none before 2026-08-21 — `.m3u8`/videos fell to the music app). Opens every file/stream/URL, GPU decode via VA-API (the freeworld driver's H.264/HEVC — a Flatpak build would not see it, same rule as browsers), Wayland-native, keyboard-driven. Config in `dotfiles/mpv.conf`: deinterlace always on + `hwdec=vaapi-copy` (see SETUP.md §1). Chosen over VLC for weight and GPU path; VLC stays the fallback if something exotic refuses to open. |
| Steam | RPM Fusion | Games. |
| Spotify | Flathub | Music. |
| Discord | Flathub | Chat. |
| Flatseal | Flathub | Flatpak permission editor. |
| Extension Manager | Flathub | GNOME extension install/update UI. |
| Beekeeper Studio | Flathub | DB client (postgres containers). |
| Podman Desktop | Flathub | Container GUI. Optional — CLI covers it; the GUI costs ~500+ MB RAM when open. |
| Unity Hub | Flathub | Game engine experiments. |
| GNOME Web (Epiphany) | Flathub | WebKit reference browser — the engine behind Safari, in its GTK port. Two jobs: (1) the closest "how would Safari render this" check without a Mac (same engine and JavaScriptCore; Apple's build differs in features/ports, so it is a strong hint, not proof); (2) Tauri v2 apps render with WebKitGTK on Linux, so a layout/CSS question gets answered by loading the page here: if Web shows it too, it is the engine, not the app (Firefox = Gecko, Chrome = Blink — neither tells you). Caveat: the flatpak bundles its own WebKitGTK (GNOME 51 runtime) while Tauri links the system `webkit2gtk4.1` (2.54 at the time of writing) — same major line, not bit-identical. |
| GNOME Tweaks | Fedora | Occasional knobs. |
| Solaar | Fedora | Logitech MX Master 3S config over Bluetooth (HID++ — no receiver needed). Package ships a system-wide autostart; device-stored settings (DPI, SmartShift) persist on their own, Solaar-side rules need it running. |

## Browsers — roles and extensions

Two browsers, two jobs. Neither is "the spare".

| Browser | Role | Why this one for the job |
|---------|------|--------------------------|
| Firefox | Daily driver: browsing, accounts, PWA (mRA OS), Music profile | The only engine where FULL uBlock Origin still runs (Chrome MV3 cut it to uBO Lite); containers for account isolation; firefoxpwa for correct Wayland desktop entries. |
| Google Chrome | Tool browser: Claude-in-Chrome (Claude Code opens tabs here when testing web work), WebHID (Qudelix), WhatsApp PWA | Claude-in-Chrome is Chromium-only; WebHID is Chromium-only; WhatsApp Web treats Chromium as first-class. Kept lean on purpose — the agent drives it, so every extension is something the agent's tabs inherit. |

(Owner's machine only, not a setup item: both browsers have DNS over
HTTPS on as a workaround for a home-network roaming glitch — SETUP.md §2
"Wi-Fi roam" TRAP. Don't propose it elsewhere.)

Extensions — each one has "read every site" power, so the list is short and
each row carries its reason. (Synced back by Firefox Sync / the Google
account; this table records the DECISIONS, `inventory/<machine-os>/browser-extensions.txt`
the raw list.)

| Extension | Browser | Why |
|-----------|---------|-----|
| uBlock Origin | Firefox | The one blocker. Extra list enabled: *AdGuard URL Tracking Protection* (Filter lists → Privacy) — strips `utm_*`/`fbclid`/`gclid`… the job ClearURLs used to do. |
| Bitwarden | both | Password manager (desktop app is the rpm; extension does autofill). |
| Firefox Multi-Account Containers | Firefox | Account/session isolation per container. |
| Translate (Chrome) | Chrome | Page/selection translation in the tool browser. In Firefox the BUILT-IN on-device translation does this (address-bar icon, right-click → Translate Selection, `about:translations`) — DeepL was removed from Firefox 2026-08-21 for that reason. |
| GNOME Shell integration | both | Needed by extensions.gnome.org to install/update shell extensions (see GNOME extensions below). |
| Progressive Web Apps for Firefox | Firefox | The firefoxpwa UI half (native host is the rpm) — SETUP.md §1. |
| FireShot | Firefox (installed, DISABLED) | Full-page capture that SCROLLS the page, so lazy-loaded content below the fold is rendered and captured; also PDF output / annotate. Firefox's built-in Ctrl+Shift+S → Save full page renders in one pass and misses not-yet-loaded sections. Kept off by default (site access) — enable for the occasional long-page capture, disable again after. |
| uBlock Origin Lite | Chrome | MV3-era blocker; the only one — no second blocker stacked (Ghostery and "I don't care about cookies" are installed-but-disabled, kept off on purpose). |
| Claude | Chrome | Claude-in-Chrome: lets Claude Code drive tabs in this profile. |
| Qudelix | Chrome | WebHID DAC config — SETUP.md §3. |
| TheTab.Ninja | Chrome | New-tab bookmark/tab manager. |
| Oceanic | Chrome | Theme only (no site access) — listed because it shows up in the inventory. |

Removed on purpose: **DeepL** from Firefox (2026-08-21) — built-in
translation (on-device, no site access) covers reading; writing-side
translation wasn't used. **ClearURLs** (2026-08-21) — no per-site allow list
exists, only a global switch, and its Google rules strip the parameters
Google AI Mode needs → "Something went wrong and an AI response wasn't
generated" on every query (worked in a private window = extensions off).
uBO's URL-tracking list does the same cleaning and can be excused per site.
**Coupert** (cashback/affiliate injector) sits disabled in Firefox — not
worth its site access. **Wappalyzer** (tech-stack profiler) is the same
pattern as FireShot: installed, disabled, switched on for the occasional
"what is this site built with" look, then off again.

## CLI stack

Wired together in `dotfiles/zshrc`:

| Tool | Role |
|------|------|
| zsh + autosuggestions + syntax-highlighting | Shell (Fedora packages, not omz). |
| starship | Prompt. |
| zoxide | `cd` with memory. |
| fzf | Fuzzy finder (Ctrl+T etc.). |
| atuin | Shell history search on Ctrl+R (`--disable-up-arrow`). |
| eza | `ls`/`ll`/`tree` replacement. |
| bat | `cat` replacement. |
| duf | `df` replacement. |
| btop | `top` replacement. |
| lazygit (`lg`) | Git TUI. |
| git-delta | Git pager/diff (config in `dotfiles/gitconfig.template`). |
| mold | Rust linker — see SETUP.md §1. |
| podman (+compose, +docker shim) | Containers; `DOCKER_HOST` points to podman socket. |
| nvme-cli, libva-utils | Diagnostics (`vainfo` is the VA-API verify tool). |
| snapper + libdnf5-plugin-actions | btrfs `pre`/`post` snapshot pair around every dnf transaction (package-level undo, not a backup) — hook file `os/fedora/assets/snapper.actions`, story in SETUP.md §2. NOT `python3-dnf-plugin-snapper` (dnf4-only, silently inert on dnf5). |
| gcloud (`google-cloud-cli`) | Google Cloud CLI via Google's official dnf repo (`/etc/yum.repos.d/google-cloud-sdk.repo`, el9 baseurl works on Fedora) — updates ride the dnf channel; extra components (kubectl etc.) are separate dnf packages, `gcloud components` is disabled in rpm installs. |
| claude-code | Claude Code via Anthropic's **native installer** (`curl -fsSL https://claude.ai/install.sh \| bash`) — binary under `~/.local/share/claude/versions/`, launcher symlink `~/.local/bin/claude`, self-updates in the background. Moved off npm/nvm 2026-08-17 (GUI apps and non-interactive shells couldn't see the nvm-managed binary; the updater kept resolving the wrong npm). **Deliberate exception to the rpm-first policy:** the official dnf repo exists but doesn't self-update, and Claude Code ships near-daily releases — the weekly `upall` cadence would lag it. |

## Dev runtimes

- Node: ONE LTS line everywhere, currently **24** (Active LTS). The system `nodejs24` rpm
  (`/usr/bin/node` — what GUI apps, systemd units and non-login shells get) and NVM's
  `default` alias both point at it; NVM keeps other lines only for projects that pin them
  in `.nvmrc`. Moved off nodejs22 2026-10-18: interactive shells ran NVM's 24 while
  `/usr/bin/node` stayed 22, so the same script ran on a different major depending on how
  it was launched. Switch: `sudo dnf install --allowerasing nodejs24 nodejs24-bin
  nodejs24-npm-bin nodejs24-full-i18n && sudo dnf remove 'nodejs22*'` (the `-bin`
  packages own `/usr/bin/node` and conflict across lines). Next move: Node 26 enters LTS
  in late October 2026 — move system + NVM default (and the Mac's brew formula) together a
  few weeks later, once pinned projects build on it. pnpm via PNPM_HOME.
  VERIFY: `/usr/bin/node -v` and `cat ~/.nvm/alias/default` → both 24.x.
- AI agent CLIs: codex, opencode-ai (npm), agy (`~/.local/bin`); claude-code is the native installer (see CLI stack).
- Rust: rustup-managed; global cargo config only sets mold.

## GNOME extensions

Enabled, each on purpose:

| Extension | Why |
|-----------|-----|
| Dash to Dock | Dock LEFT, fixed, 28px icons, multi-monitor. **Trap:** its default `<Super>q` show-dock hotkey shadowed the close-window binding once — took two debugging passes to find (schemas are invisible to plain `gsettings list-schemas`). Settings in inventory dconf. |
| Blur my shell | Panel/dock/overview blur. Settings in inventory dconf. |
| Battery Health Charging | Charge limiter (`bal` mode) — battery longevity on a mostly-docked laptop. |
| Vitals | Load/CPU/temp/RAM in top bar — the first-glance thermal indicator. |
| Clipboard Indicator | Clipboard history. |
| Caffeine | On-demand sleep inhibit (normally off). |
| AppIndicator Support | Tray icons for legacy apps (Discord etc.). |
| GSConnect | Phone integration (KDE Connect). **Pairing is per-device state — re-pair manually on a new machine; its dconf is deliberately not in the repo (certificate/device ids).** |
| Background Logo | Fedora default, harmless, left as-is. |

Installed-but-disabled (`apps-menu`, `places-menu`, `window-list`,
`launch-new-instance`, `user-theme`): stock GNOME "classic" extensions that
ship with Fedora — not used, nothing to do. `user-theme` stays disabled on
purpose (stale shell themes silently corrupt GNOME layout — SETUP.md §2).

## macOS (`mbp14`) — where it differs

Same intent, platform mechanics: everything native via Homebrew (formulae
for CLI, casks for apps, `mas` for the App Store); the tables above still
hold the WHY. Only the rows that change are listed — details in SETUP.md
§2c / §3b. Rows marked *[role]* exist because this Mac is the owner's
always-on home server — not a default for any other Mac.

| Fedora row | On the Mac | Why |
|------------|------------|-----|
| mpv as THE player | **IINA** (mpv-based, native UI) owns video/stream types; `mpv` CLI also installed | IINA reads `~/.config/mpv` — one mpv.conf for both. |
| WhatsApp Chrome PWA | **WhatsApp** native app (cask) | The PWA was a Linux workaround; the native app exists here. |
| GNOME Web (WebKit reference) | **Safari** itself | The real engine — no proxy needed. |
| Solaar / MX Master | — | Apple Magic Mouse + Keyboard at that desk; no Logi Options+. |
| Flatseal, Extension Manager, GNOME Tweaks | — | No equivalent needed. |
| Steam | — | Not on this Mac. |
| mold | — (Apple `ld_prime`) | mold has no Mach-O backend. |
| podman-docker shim | `alias docker=podman` | podman runs in `podman machine`. |
| nodejs24 (dnf) | `node@24` (brew, force-linked) + nvm | Same shape and the same ONE LTS line as Fedora (see Dev runtimes). |
| — | **Karabiner-Elements** | Linux shortcut muscle memory on a Mac keyboard, scoped away from terminals. |
| — | **gh**, **tmux**, **jq** | gh: auth for private repos (no SSH keys on the Mac); tmux: remote sessions survive SSH drops; jq: a Claude Code hook needs it. |
| — | **Tailscale** (formula, system daemon) *[role]* | Reach the home server from outside; daemon so it's up before login. |
| — | **Xcode** (App Store) *[role]* | iOS simulator testing. |
| — | **agy** (Antigravity CLI) | On Fedora too (`~/.local/bin`); first recorded here. |

## Windows (`thinkpad-p14s` dual-boot slice) — where it differs

Occasional-use slice, small partition: only the rows below were installed
(winget, 2026-10-24). Details in SETUP.md §2b.

| Fedora row | On Windows | Why |
|------------|------------|-----|
| zsh + plugins | **PowerShell 7** + PSReadLine predictions + PSFzf | No native zsh; same tools wired in `dotfiles/windows/profile.ps1`. |
| Ghostty | **Windows Terminal** (preinstalled) | No Ghostty build; Catppuccin Mocha + JetBrainsMono Nerd Font in its own config. |
| btop | **btop4win** | Windows port, same author. |
| mpv (RPM Fusion) | **mpv** (`shinchiro.mpv`) | `hwdec=d3d11va-copy`. |
| Firefox (daily driver) | — **Chrome is the default here** | Owner's choice for this slice; extensions sync via the Google account. |
| WhatsApp Chrome PWA | **WhatsApp** native (Store, preinstalled) | Native app exists here, as on the Mac. |
| Battery Health Charging | **Lenovo Vantage** charge threshold 75/80 | Same firmware knobs. |
| Caffeine | **PowerToys** (Awake only) | Every other module off. |
| GSConnect | **Phone Link** (preinstalled, kept) | |
| Solaar | — | Logi Options+ not wanted on this slice. |
| nodejs24 (dnf) | `OpenJS.NodeJS.LTS` pinned to `24.*` | Keeps the ONE LTS line when winget's LTS moves to 26. |
| Rust + mold | **Rust** (rustup minimal, msvc) + **VS Build Tools 2022** C++ workload; no mold | Tauri release builds here (added 2026-10-24); mold has no PE/COFF backend, MSVC `link.exe` links. |
| codex/opencode/agy, podman, gcloud, Steam, Discord, Unity Hub, Beekeeper, Flatpak tools | — | Not on this slice (occasional use, disk). |

## Removed on purpose

- **karere** (WhatsApp wrapper flatpak) → replaced by the Firefox PWA
  (2026-07-30). Same content cost, one less app to maintain.
- **EasyEffects** (2026-08-06) → speaker-boost premise died under a real
  A/B: at any crackle-free gain the DSP chain matched plain output loudness
  while sounding muddier — the tiny drivers' physical ceiling IS bypass
  level. With every output on bypass it was pure overhead (RAM, an
  autostart, and a silent-DSP-loss failure mode when its stream capture
  broke). Presets survive in `~/.var/app/...` for any future revisit;
  full story in SETUP.md §3.
