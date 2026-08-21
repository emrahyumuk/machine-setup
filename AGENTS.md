# Agent Onboarding Protocol

You are an AI agent opened inside a clone of this repo. When the user asks to
be "set up", "apply this", or anything similar, follow this protocol. Do not
bulk-apply the manifest — it describes ONE person's machine; your job is to
adapt it to THIS user on THIS machine, interactively.

## Step 0 — Language, then who is this?

**First question, before anything else: language.** Offer "Continue in
English" plus a free-text field ("or type the language you want"). From then
on every explanation, checklist line, question and report is in that
language. The repo's own files stay English no matter what (SETUP.md
additions, a forked repo's content — see Step 6): English is the repo's
language, the user's language is the conversation's.

**Second question: who is this?** Three answers, not two — the owner ports
this setup to other machines too, and the hardware layer only follows the
hardware:

- **Owner, THIS laptop** (another OS on the same machine — e.g. the Windows
  dual-boot slice, see HARDWARE.md and `machines/`) → everything is in
  scope: personal layer, OS layer translated, AND that machine's hardware
  section (§3a for the ThinkPad; same hardware, so apply the items' intent
  via the platform's tools — see "Owner on a NEW OS").
- **Owner, ANOTHER machine** (a MacBook, a desktop…) → personal layer and OS
  layer in scope; §3 is NOT — survey the new hardware and re-decide each §3
  item from scratch (charge limit, GPU memory, DAC quirks are all
  per-machine). What you apply becomes a new hardware section.
- **Someone else** → owner-specific items default to SKIP: the personal apps
  and PWA/icon setup (SETUP.md §1 Firefox parts), the Claude Code entry's
  dot-claude-config repo (private — unreachable for non-owners; offer only
  its allowlist-gitignore PATTERN for their own `~/.claude`), the entire
  hardware section (§3), and `dotfiles/` contents (offer as examples to
  cherry-pick, never install as-is). What remains genuinely portable: the
  CLI stack, Rust/mold, and the OS layers (§2, §2b…) where assumptions
  hold. ("§3" below means the hardware layer: §3a, §3b… one per machine.)

## Step 1 — Survey the machine (read-only)

Detect before proposing: OS + version, package manager, desktop environment,
CPU/GPU vendor, RAM, laptop vs desktop, swap/zram situation, what from
APPS.md is already installed. Never assume Fedora — check.

**Which machine is this?** Read the DMI product name (Linux:
`/sys/class/dmi/id/product_name`; Windows: `Get-CimInstance Win32_ComputerSystem`;
macOS: `system_profiler SPHardwareDataType`) and the OS, then look in
`machines/` for a record with the same `model:` + `os:`. One match → "I
recognise this machine: <file>, last verified <date>". Several (two
identical models) → use `hostname:` to break the tie, else ask. None → a
new machine: propose the short name from the model (`thinkpad-t14`,
`mbp14`, `desk-b650`), let the user adjust, and create
`machines/<hardware>-<os>.md` + `hardware/<hardware>.md` as part of the
session (owner) or of Step 6 (someone else). Suggest a static hostname in
the same shape if the current one is generic/unset. Never write serials,
MACs or keys into these files.

**Freshness.** Each machine record carries `last-verified`. A layer older
than **90 days** (or never verified) is a CACHE of mechanics, not truth:
say so ("§2b was last verified on DATE"), run each item's VERIFY before
trusting it, re-check package ids/paths/commands against current sources
(research allowed — say when you did), and prefer the item's WHY over its
HOW. The primary machine's layer is the reference for DECISIONS: a decision
present there but missing from this OS's layer is a gap — offer it
("Fedora has snapshots before every package transaction; the Windows
equivalent is System Restore points before winget upgrades — add it?"),
don't silently skip it. Staleness is surfaced, never hidden.

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
3. Git: `gitconfig.template` + identity (ASK for the Git host username
   and email — the only place the protocol asks for personal data; it goes
   into `~/.gitconfig` on the machine, never into the repo; suggest the
   username, not the full name, for `user.name` — see SETUP.md §1) + the OS's line-ending setting where one
   applies (§2b on Windows). Each setting with its one-line reason.
4. Rust dev: mold linker + cargo config
5. Hardware video decode (Fedora/mesa only — §2 VA-API; on other platforms,
   translate the intent)
6. zram + VM tuning (Linux only — read the ASSUMES lines carefully)
7. GNOME desktop: extensions (each listed individually with its purpose from
   APPS.md) + settings (inventory/ is the owner's reference state, not a
   mandate). **Subjective look-and-feel is ASKED, never inherited silently**:
   dark/light, accent color, dock position, fonts are the user's taste —
   ask, then apply linked pairs consistently (e.g. dark mode = `color-scheme`
   AND the gtk-3.0 dark flag together; see SETUP.md §2 theming).
8. Personal apps & PWAs (owner-specific — examples only for non-owners)

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
- **Print the plan first**: before the first command runs, list the exact
  commands/changes you are about to make for the selected items (one block,
  grouped by item). The user sees the whole shape before any permission
  prompt; surprises are caught here, not mid-run.
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
- If `os/<os>/bootstrap` exists for this OS (Fedora today), the items it
  covers may be applied by running that script once (with the user's
  consent) instead of re-implementing them one by one — it is the
  deterministic form of those exact decisions. Still run the per-item VERIFY
  lines afterwards (`os/<os>/verify`). Note it overwrites its config files
  unconditionally; if the survey found user-customized versions, apply
  per-item instead.

## Step 4 — Report and hand off

End with four lists: applied (with verify results), already satisfied,
skipped (with reasons), no-equivalent (with suggestions). If the user is not
the owner, offer Step 6 — turning what was just applied into their own repo
— instead of leaving them with a clone of someone else's manifest.

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
cross-reference keep their numbers. New hardware gets `## 3b. …` and
`hardware/<name>.md`. **A port also produces its mechanics**: from what was
actually applied, write `os/<os>/bootstrap` (the judgment-free part —
package-manager lines, config copies, default handlers), `os/<os>/verify`
(every VERIFY line of the new layer as PASS/FAIL) and `os/<os>/collect`
(inventory + dotfiles + machine-record stamps), in the platform's native
script language (`.ps1` on Windows, `.sh` on macOS). Fill or create
`machines/<hardware>-<os>.md` with the stamps. The second run on that OS is
then one script + VERIFY, like Fedora today.

On the owner's laptop, Windows is the dual-boot slice described in
HARDWARE.md — same hardware, so §3a items are in scope there too
(translated: charge limit → vendor tool, WebHID app → Chrome on Windows,
BIOS items already done and OS-independent). Commit the port on its own
branch (e.g. `windows-port`) for review from the primary OS.

## Step 5 — Your own recommendations (beyond the manifest)

The survey usually reveals things this repo doesn't cover. After the report,
offer them — **clearly labeled as YOUR suggestions, not the owner's
manifest**: missing safety layers (no backups, no firewall, EOL OS version),
outdated GPU drivers, obvious wins for THIS user's workload the manifest
never anticipated. Same rules apply: explain what/why, let the user pick,
ask before system-level changes.


## Step 6 — Make it theirs (offered to non-owners; optional)

After the report, ask: **"Want this turned into your own machine-setup
repo — what you actually installed today, as a manifest you can re-apply
and grow?"** If yes:

1. Ask **public or private**, and the repo name (default `machine-setup`).
2. Create it (`gh repo create` when available, otherwise init locally and
   print the push commands) — never push to THIS repo's origin.
3. Seed it with this repo's SKELETON, not its content: README (rewritten:
   their name on the Owner line, the same intent-over-commands purpose,
   the privacy rule verbatim), AGENTS.md and `.claude/commands/setup.md`
   unchanged (the protocol is the reusable part), `.gitattributes`,
   `machines/README.md`, and empty `inventory/`, `dotfiles/`, `os/`,
   `hardware/`. The owner's `machines/*`, `hardware/*`, `inventory/*` and
   `os/*` do NOT cross over — they describe the owner's machines.
4. Write THEIR manifest from the session (plus `machines/<hardware>-<os>.md`
   and `hardware/<hardware>.md` for their machine, named from the Step 1
   survey): `SETUP.md` §1 personal (what they
   chose), §2 OS-specific for the OS they are on (each applied item with
   WHAT/WHY/VERIFY as it was actually done — the Windows/macOS mechanics
   from this session, not the owner's Fedora ones), §3 hardware only if a
   hardware item was applied, §4 "deliberately not done" from what they
   declined and why. `APPS.md` = only the rows they selected, with the
   reasons they agreed with. Owner-specific items (PWAs, icons, private
   repos, the owner's hardware) do not cross over.
5. Repo language stays **English** (the conversation language from Step 0
   does not apply to repo files); remind them of the privacy rule before
   the first push: config only, never state/identity/secrets.
6. Tell them how it grows: every future machine-level decision → SETUP.md
   with its WHY, same sitting; their `os/<os>/{bootstrap,verify,collect}`
   come out of this very session (write them — the same rule as "Owner on
   a NEW OS"), and `machines/<their-hardware>-<os>.md` starts stamped today.

## Hard rules

- Respect the privacy rule (README): never write identities, certificates,
  pairing state, or secrets into the repo.
- Never push to this repo's origin — it belongs to the owner.
- Prefer reversible steps; state the rollback for anything system-level.
