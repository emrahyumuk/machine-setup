# Agent Onboarding Protocol

You are an AI agent opened inside a clone of this repo. When the user asks to
be "set up", "apply this", or anything similar, follow this protocol. Do not
bulk-apply the manifest — it describes ONE person's machine; your job is to
adapt it to THIS user on THIS machine, interactively.

## Step 0 — Who is this?

Ask one question first: **"Are you the repo owner restoring/porting your own
machine, or someone else adapting this setup?"**

- **Owner** → everything is in scope, including the personal layer and
  hardware section (still verify hardware matches before applying §3 items).
- **Someone else** → owner-specific items default to SKIP: the personal apps
  and PWA/icon setup (SETUP.md §1 Firefox parts), the Claude Code entry's
  dot-claude-config repo (private — unreachable for non-owners; offer only
  its allowlist-gitignore PATTERN for their own `~/.claude`), the entire
  hardware section (§3), and `dotfiles/` contents (offer as examples to
  cherry-pick, never install as-is). What remains genuinely portable: the CLI stack, Rust/mold,
  and the OS layer (§2) where assumptions hold.

## Step 1 — Survey the machine (read-only)

Detect before proposing: OS + version, package manager, desktop environment,
CPU/GPU vendor, RAM, laptop vs desktop, swap/zram situation, what from
APPS.md is already installed. Never assume Fedora — check.

**Browsers are asked, not assumed.** Ask which browser is the user's daily
driver (and whether a second one has a job — e.g. Claude-in-Chrome, WebHID,
a PWA). APPS.md "Browsers" is written for Firefox-primary + Chrome-as-tool;
map by ENGINE, not by name: Gecko (Firefox, LibreWolf, Zen, Floorp…) takes
the Firefox rows as-is (full uBlock Origin, containers, firefoxpwa); any
Chromium (Chrome, Brave, Edge, Vivaldi, Chromium) takes the Chrome rows
(uBO Lite, no second blocker; Claude-in-Chrome and WebHID are
Chromium-only). Brave already ships a blocker — then no uBO Lite on top.
Extensions are offered one by one with their why, like everything else;
the owner's choices are not a mandate.

**Already-installed items never reach the menu.** Check every candidate
(package manager query, `command -v`, extension list) and drop satisfied
ones into the "already satisfied" bucket of the final report instead of
asking about them.

## Step 2 — Scope with the user: an ANNOTATED CHECKLIST, never a fait accompli

Nothing is installed before the user has seen and selected it. Build a
checklist from SETUP.md + APPS.md where every item carries:

- **what it is** (one line, plain words — assume the user never read SETUP.md),
- **why they might want it** (the item's WHY, compressed),
- **your recommendation for THIS machine** (fits / already satisfied / doesn't
  apply — with the reason).

**Two steps, in this order — SHOW, then SELECT.** (Lesson from the first
Windows port, 2026-08-21: asking "all / per group / per item?" up front and
then using a chip-style question widget produced group lumps with no
per-item explanation — the widget's option text cannot carry the
annotation, and "per group" read as "hide the items". Don't.)

1. **SHOW — print the whole annotated checklist as plain text in the
   conversation first.** Group headings for navigation, and under each
   heading one line per item:
   `[ ] name — what it is — why you'd want it — recommendation for THIS
   machine (fits / already installed / no equivalent → alternative)`.
   Every item, every time, before any selection prompt. If the user asks
   "what does X do?", expand from SETUP.md/APPS.md before they decide.
2. **SELECT — only after the list is on screen.** Accept free text ("just
   eza, bat and lazygit", "all of group 1 except zoxide", "everything
   recommended") and/or a native multi-select widget if the platform has
   one (Claude Code's multi-select question tool, up to 4 options per
   question). The widget is a ticking aid, not the carrier of the list: its
   option labels repeat the item name + one-line purpose, never a group
   name alone. "Select all" / "whole group N" are shortcuts the user may
   use in their reply — not a mode you ask them to pick before they have
   seen the items.

**Groups are for navigation only — selection and annotation are PER ITEM.**
Never present "CLI stack" or "GNOME extensions" as a single yes/no lump:
each tool, extension and app gets its own checklist line with its one-line
purpose, pulled from APPS.md (that file exists precisely to feed this menu —
e.g. "zoxide — cd with memory", "Vitals — CPU/temp/RAM in the top bar").

Typical groups:

1. CLI tools (each listed individually — APPS.md "CLI stack" table +
   dotfiles/zshrc as reference for wiring)
2. Applications (APPS.md "Desktop applications" table: dnf/flatpak apps —
   each with its why; skip owner-specific rows for non-owners)
   + browser extensions (APPS.md "Browsers": per the engine mapping from
   Step 1; the owner-specific ones — Qudelix, TheTab.Ninja, PWA helper —
   are examples for non-owners)
3. Rust dev: mold linker + cargo config
4. Hardware video decode (Fedora/mesa only — §2 VA-API; on other platforms,
   translate the intent)
5. zram + VM tuning (Linux only — read the ASSUMES lines carefully)
6. GNOME desktop: extensions (each listed individually with its purpose from
   APPS.md) + settings (inventory/ is the owner's reference state, not a
   mandate). **Subjective look-and-feel is ASKED, never inherited silently**:
   dark/light, accent color, dock position, fonts are the user's taste —
   ask, then apply linked pairs consistently (e.g. dark mode = `color-scheme`
   AND the gtk-3.0 dark flag together; see SETUP.md §2 theming).
7. Personal apps & PWAs (owner-specific — examples only for non-owners)

Small machines/VMs: warn where a tuning doesn't fit. Unselected items are
never applied; system-level ones are re-confirmed individually at apply time
(Step 3) even when selected here.

## Step 3 — Apply, item by item

- **Run the item's VERIFY line FIRST** (or its platform equivalent) where one
  exists: if it already passes, mark the item *already satisfied* and skip —
  don't install what the platform ships correctly (e.g. Ubuntu's mesa passes
  the H.264 check that Fedora's fails; the whole VA-API item then vanishes).
- Check the item's **ASSUMES** line against the surveyed machine; if it
  fails, say so and skip or adapt (e.g. swappiness=150 is zram-only).
- Translate mechanics to the platform (dnf → apt/pacman/brew/winget; sysctl
  → the platform's equivalent or "no equivalent").
- **Ask before every system-level change** (root/admin, BIOS advice, kernel
  params). Batch user-level changes if the user prefers.
- Run the item's **VERIFY** line (or its platform equivalent) after applying.
- No equivalent on this platform? Say so explicitly and suggest the closest
  alternative — don't silently drop items.
- **How to pick an alternative** (the owner's Fedora choices were researched
  and argued, not defaulted — hold the port to the same bar):
  1. Read the item's WHY first and carry the *intent*, not the tool name
     (e.g. "browsers stay native so the host codec fix applies" → on
     Windows the intent is "native installer, not a sandboxed store build").
  2. Prefer, in order: what the platform ships first-party (PowerShell 7,
     Windows Terminal, winget; macOS built-ins, brew) → the mainstream
     community standard → niche tools only if the WHY demands them.
  3. If the choice is contested or trades something off (winget vs scoop,
     WSL2 vs native Podman, Store vs vendor installer), DO NOT pick silently:
     offer 2-3 options with one-line trade-offs and let the user choose. You
     may research current state (web) before offering — say when you did.
  4. Label every such pick as YOUR suggestion, not the owner's manifest
     (same rule as Step 5), and record pick + reasoning in the new OS
     section of SETUP.md so the next port inherits a decision, not a guess.
- On Fedora, the items `bootstrap-fedora.sh` covers may be applied by running
  that script once (with the user's consent) instead of re-implementing them
  one by one — it is the deterministic form of those exact decisions. Still
  run the per-item VERIFY lines afterwards. Note it overwrites its config
  files unconditionally; if the survey found user-customized versions, apply
  per-item instead.

## Step 4 — Report and hand off

End with four lists: applied (with verify results), already satisfied,
skipped (with reasons), no-equivalent (with suggestions). If the user is not
the owner, recommend they fork: set their own Owner line, prune the
personal/hardware layers, regenerate `inventory/` with `collect.sh` (Fedora)
or note their platform's equivalent, and adopt the maintenance rules in
README.

## Owner on a NEW OS or machine — grow the manifest

When the user IS the owner applying this on a new OS (macOS, Windows, another
distro) or new hardware: after applying, **append what was actually done to
SETUP.md** as a new OS-layer or hardware section — WHAT/WHY/VERIFY, written
from the real session, same-sitting rule. Items that turned out "already
native on this platform" (e.g. memory compression on macOS/Windows, hardware
video decode) get one line saying so, so the next port doesn't re-litigate
them. The manifest grows from real sessions, never from speculation.

Placement: a new OS layer goes right after the existing one as
`## 2b. OS-specific — <OS>` (then 2c…); §1/§3/§4 and every existing "§2"
cross-reference keep their numbers. On the owner's laptop, Windows is the
dual-boot slice described in HARDWARE.md — same hardware, so §3 items are
in scope there too (translated: charge limit → vendor tool, WebHID app →
Chrome on Windows, BIOS items already done and OS-independent). Commit the
port on its own branch (e.g. `windows-port`) for review from the primary OS.

## Step 5 — Your own recommendations (beyond the manifest)

The survey usually reveals things this repo doesn't cover. After the report,
offer them — **clearly labeled as YOUR suggestions, not the owner's
manifest**: missing safety layers (no backups, no firewall, EOL OS version),
outdated GPU drivers, obvious wins for THIS user's workload the manifest
never anticipated. Same rules apply: explain what/why, let the user pick,
ask before system-level changes.

## Hard rules

- Respect the privacy rule (README): never write identities, certificates,
  pairing state, or secrets into the repo.
- Never push to this repo's origin — it belongs to the owner.
- Prefer reversible steps; state the rollback for anything system-level.
