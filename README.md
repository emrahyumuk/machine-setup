# machine-setup

My machine, reproducible — and readable by humans *and* AI agents.

## Goals

1. **Rebuild this exact machine.** Fresh Fedora on this ThinkPad → run the
   bootstrap, apply the manifest, restore the inventory → same machine.
2. **Port to another Fedora machine.** Feed `SETUP.md` to an AI agent on the
   target; it adapts each item to that hardware (the manifest carries the
   WHY/ASSUMES lines that make safe adaptation possible).
3. **Adapt to any OS.** Another distro, macOS, Windows — an agent maps each
   item to the platform's equivalent, or tells you there isn't one and
   suggests alternatives. Intent ports; commands don't.

It doubles as a "uses" page: what I run, how it's configured, and — just as
important — what I decided *against* and why.

## Layout

| Path | What |
|------|------|
| `SETUP.md` | The manifest: every decision with WHAT / WHY / VERIFY / ASSUMES, in layers (§1 personal → §2/§2b/… per OS → §3a/§3b… per hardware → §4 deliberately NOT done). Source of truth; one file on purpose — decisions read as one document. |
| `APPS.md` | Curated, annotated app/tool/extension list — what is installed on purpose and why. The human/agent-facing view. |
| `HARDWARE.md` + `hardware/<name>.md` | The desk (shared peripherals) + one file per machine. |
| `machines/<hardware>-<os>.md` | One record per (machine, OS): model, role, which layers apply, and freshness stamps (`last-applied` / `last-collected` / `last-verified`). Agents match here first; staleness is visible here, not hidden. |
| `os/<os>/` | Per-OS mechanics: `bootstrap` (judgment-free base), `verify` (every VERIFY line as PASS/FAIL — installed as `machine-verify`, run by `upall`), `collect` (regenerates inventory + dotfiles, stamps the machine record), notifier scripts, systemd units/assets. Today: `os/fedora/`. A port produces its own `os/<os>/` from its session. |
| `inventory/<hardware>-<os>/` | Generated state per machine: raw package list (appendix), flatpaks, GNOME/browser extensions, whitelisted dconf, dev globals. Never hand-edited. |
| `dotfiles/` | Verbatim copies of zshrc, ghostty, starship, mpv configs; `gitconfig.template` is sanitized (identity set per machine). Shared across OSes where the tool exists; per-OS files go under `dotfiles/<os>/` when one appears. |

## Privacy rule

The repo holds **config (deliberate choices), never state** (pairing data,
certificates, device ids, identities, caches). dconf collection is a
whitelist; GSConnect's tree is excluded entirely — re-pair devices manually
on a new machine. `.gitconfig` identity is never committed.

## Cloned this and it's not your machine?

```bash
git clone <this-repo> && cd machine-setup
claude        # or any coding agent that reads AGENTS.md / CLAUDE.md
```

Then type **`/setup`** (Claude Code — the command ships with the repo), or
just say **"Set up my machine from this repo."** (any agent).

What happens next (the agent follows `AGENTS.md`):

1. It surveys your OS/hardware and what you already have — anything already
   installed is filtered out, you're never asked about it.
2. You get an **annotated checklist**: every tool, app and extension as its
   own line with a one-line "what it does / why you'd want it" and a
   recommendation for your machine. Pick with checkboxes or free text
   ("just eza, bat and lazygit"). Owner-specific parts are skipped by
   default.
3. It applies only what you selected, re-confirms each system-level change
   individually, and runs each item's VERIFY check.
4. You get a report (applied / already satisfied / skipped / no-equivalent
   with alternatives) — plus the agent's own suggestions for things it
   noticed that this repo doesn't cover, clearly labeled as such.
5. Optional: it offers to turn what you just installed into YOUR OWN repo
   (public or private, your name on it, the same protocol inside) — so you
   leave with a manifest of your machine, not a clone of someone else's.

It asks for your language first; everything it says to you comes in that
language, while repo files stay English.

Works on other distros/OSes too — items with no equivalent get flagged with
alternatives instead of silently dropped. No AI at hand? `SETUP.md` reads
fine as a human document; `os/fedora/bootstrap.sh` covers the mechanical base
on Fedora.

## Fresh machine procedure (owner)

1. Fedora: run `os/fedora/bootstrap.sh`. Other OS: its `os/<os>/bootstrap`
   if a port produced one, else skip.
2. Install from inventory: `inventory/thinkpad-p14s-fedora/packages-dnf-raw.txt`
   (dnf, appendix — APPS.md is the intent), `flatpaks.txt` (flathub),
   `gnome-extensions.txt`, then load `gnome-settings.dconf` per-namespace
   with `dconf load`.
3. Hand `SETUP.md` to an AI agent:

   > Apply this manifest to this machine. Adapt each item to the current
   > OS/hardware, respect every ASSUMES line, skip anything already satisfied,
   > verify each item with its VERIFY line. The hardware section does not
   > auto-port — evaluate it against the actual hardware. If an item has no
   > equivalent on this platform, say so and suggest the closest alternative.
   > Ask before anything destructive.

4. Walk the hardware section of `SETUP.md` manually — it never auto-ports.

## Maintenance rules

- New machine-level decision (a tuning, a workaround, a "decided against X")
  → add to `SETUP.md` **with its WHY and VERIFY, in the same sitting**.
  An entry without a WHY will either be blindly ported somewhere it harms,
  or deleted because nobody remembers it.
- Installed/removed something? → `os/fedora/collect.sh` (or the OS's
  collect), review the diff, commit. It also stamps `machines/<id>.md`.

## Not yet covered

- Firefox profile contents (bookmarks, extensions' own settings) — sync/manual.
- (Claude Code config+memory used to sit here — covered since 2026-08-20 by
  the private dot-claude-config sync repo; see SETUP.md §1.)
