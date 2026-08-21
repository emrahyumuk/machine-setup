# Applications & Tools — curated

What is installed **on purpose** and why. The raw generated lists live in
`inventory/` (appendix; includes noise like libs and preinstalled defaults —
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
| firefoxpwa (PWAsForFirefox) | rpm + extension | PWAs as real apps: mra-agent, mRA Notes. (WhatsApp moved to a Chrome PWA 2026-08-18 — messages intermittently stalled in the Firefox PWA; WhatsApp Web treats Chromium as first-class.) See SETUP.md §1 for icon + link-handling config. |
| Google Chrome | Google repo | Tool browser — Claude-in-Chrome, WebHID (Qudelix 5K `--app` window, XWayland — see SETUP.md hardware notes), WhatsApp PWA. Roles + extensions in "Browsers" below. |
| Ghostty | COPR | Terminal. Config in `dotfiles/ghostty.config` (Catppuccin Mocha, JetBrainsMono Nerd Font). |
| VS Code (`code`) | Microsoft repo | Editor. |
| Neovim | Fedora | `vim`/`EDITOR` alias target. |
| Thunderbird | Fedora | Mail. |
| Steam | RPM Fusion | Games. |
| Spotify | Flathub | Music. |
| Discord | Flathub | Chat. |
| Flatseal | Flathub | Flatpak permission editor. |
| Extension Manager | Flathub | GNOME extension install/update UI. |
| Beekeeper Studio | Flathub | DB client (postgres containers). |
| Podman Desktop | Flathub | Container GUI. Optional — CLI covers it; the GUI costs ~500+ MB RAM when open. |
| Unity Hub | Flathub | Game engine experiments. |
| GNOME Tweaks | Fedora | Occasional knobs. |
| Solaar | Fedora | Logitech MX Master 3S config over Bluetooth (HID++ — no receiver needed). Package ships a system-wide autostart; device-stored settings (DPI, SmartShift) persist on their own, Solaar-side rules need it running. |

## Browsers — roles and extensions

Two browsers, two jobs. Neither is "the spare".

| Browser | Role | Why this one for the job |
|---------|------|--------------------------|
| Firefox | Daily driver: browsing, accounts, PWAs (mra-agent, mRA Notes), Music profile | The only engine where FULL uBlock Origin still runs (Chrome MV3 cut it to uBO Lite); containers for account isolation; firefoxpwa for correct Wayland desktop entries. |
| Google Chrome | Tool browser: Claude-in-Chrome (Claude Code opens tabs here when testing web work), WebHID (Qudelix), WhatsApp PWA | Claude-in-Chrome is Chromium-only; WebHID is Chromium-only; WhatsApp Web treats Chromium as first-class. Kept lean on purpose — the agent drives it, so every extension is something the agent's tabs inherit. |

Extensions — each one has "read every site" power, so the list is short and
each row carries its reason. (Synced back by Firefox Sync / the Google
account; this table records the DECISIONS, `inventory/browser-extensions.txt`
the raw list.)

| Extension | Browser | Why |
|-----------|---------|-----|
| uBlock Origin | Firefox | The one blocker. Extra list enabled: *AdGuard URL Tracking Protection* (Filter lists → Privacy) — strips `utm_*`/`fbclid`/`gclid`… the job ClearURLs used to do. |
| Bitwarden | both | Password manager (desktop app is the rpm; extension does autofill). |
| Firefox Multi-Account Containers | Firefox | Account/session isolation per container. |
| DeepL | both (Translate in Chrome) | Translation for writing; Firefox's built-in on-device translation covers reading. |
| GNOME Shell integration | both | Needed by extensions.gnome.org to install/update shell extensions (see GNOME extensions below). |
| Progressive Web Apps for Firefox | Firefox | The firefoxpwa UI half (native host is the rpm) — SETUP.md §1. |
| FireShot | Firefox (installed, DISABLED) | Full-page capture that SCROLLS the page, so lazy-loaded content below the fold is rendered and captured; also PDF output / annotate. Firefox's built-in Ctrl+Shift+S → Save full page renders in one pass and misses not-yet-loaded sections. Kept off by default (site access) — enable for the occasional long-page capture, disable again after. |
| uBlock Origin Lite | Chrome | MV3-era blocker; the only one — no second blocker stacked (Ghostery and "I don't care about cookies" are installed-but-disabled, kept off on purpose). |
| Claude | Chrome | Claude-in-Chrome: lets Claude Code drive tabs in this profile. |
| Qudelix | Chrome | WebHID DAC config — SETUP.md §3. |
| TheTab.Ninja | Chrome | New-tab bookmark/tab manager. |
| Oceanic | Chrome | Theme only (no site access) — listed because it shows up in the inventory. |

Removed on purpose: **ClearURLs** (2026-08-21) — no per-site allow list
exists, only a global switch, and its Google rules strip the parameters
Google AI Mode needs → "Something went wrong and an AI response wasn't
generated" on every query (worked in a private window = extensions off).
uBO's URL-tracking list does the same cleaning and can be excused per site.
**Coupert** (cashback/affiliate injector) and **Wappalyzer** sit disabled in
Firefox — not worth their site access.

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
| snapper + libdnf5-plugin-actions | btrfs `pre`/`post` snapshot pair around every dnf transaction (package-level undo, not a backup) — hook file `assets/snapper.actions`, story in SETUP.md §2. NOT `python3-dnf-plugin-snapper` (dnf4-only, silently inert on dnf5). |
| gcloud (`google-cloud-cli`) | Google Cloud CLI via Google's official dnf repo (`/etc/yum.repos.d/google-cloud-sdk.repo`, el9 baseurl works on Fedora) — updates ride the dnf channel; extra components (kubectl etc.) are separate dnf packages, `gcloud components` is disabled in rpm installs. |
| claude-code | Claude Code via Anthropic's **native installer** (`curl -fsSL https://claude.ai/install.sh \| bash`) — binary under `~/.local/share/claude/versions/`, launcher symlink `~/.local/bin/claude`, self-updates in the background. Moved off npm/nvm 2026-08-17 (GUI apps and non-interactive shells couldn't see the nvm-managed binary; the updater kept resolving the wrong npm). **Deliberate exception to the rpm-first policy:** the official dnf repo exists but doesn't self-update, and Claude Code ships near-daily releases — the weekly `upall` cadence would lag it. |

## Dev runtimes

- Node: nodejs22 (system) + NVM for per-project versions; pnpm via PNPM_HOME.
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
