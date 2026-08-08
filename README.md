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
| `SETUP.md` | The manifest: every decision with WHAT / WHY / VERIFY / ASSUMES, in three layers (personal → OS → hardware) + a deliberately-NOT-done list. Source of truth. |
| `APPS.md` | Curated, annotated app/tool/extension list — what is installed on purpose and why. The human/agent-facing view. |
| `HARDWARE.md` | The physical desk: laptop, peripherals, what drives what. |
| `bootstrap-fedora.sh` | Mechanical base for Fedora: repos, packages, config files that need no judgment. Idempotent. |
| `collect.sh` | Regenerates `inventory/` + `dotfiles/` from the live machine. Whitelist-based (see its privacy rule). |
| `inventory/` | Generated state: raw dnf list (appendix), flatpaks, GNOME extensions, whitelisted dconf namespaces, dev globals. Never hand-edited. |
| `dotfiles/` | Verbatim copies of zshrc + ghostty config; `gitconfig.template` is sanitized (identity set per machine). |
| `assets/` | Files the manifest references (e.g. the WhatsApp PWA icon source). |

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

Works on other distros/OSes too — items with no equivalent get flagged with
alternatives instead of silently dropped. No AI at hand? `SETUP.md` reads
fine as a human document; `bootstrap-fedora.sh` covers the mechanical base
on Fedora.

## Fresh machine procedure (owner)

1. Fedora: run `./bootstrap-fedora.sh`. Other OS: skip.
2. Install from inventory: `inventory/packages-dnf.txt` (dnf),
   `inventory/flatpaks.txt` (flathub), `inventory/gnome-extensions.txt`,
   then load `inventory/gnome-settings.dconf` per-namespace with `dconf load`.
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
- Installed/removed something? → `./collect.sh`, review the diff, commit.

## Not yet covered

- Firefox profile contents (bookmarks, extensions' own settings) — sync/manual.
- Claude Code memory dir (`~/.claude/projects/*/memory/`) — machine quirks
  live there too; copy the relevant quirk files' content into new machines'
  AI context when porting.
