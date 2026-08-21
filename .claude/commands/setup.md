---
description: Interactive machine setup from this repo's manifest (AGENTS.md protocol)
---

Read AGENTS.md in this repository and execute its protocol end to end for
the current user and machine:

1. Ask the conversation language first ("Continue in English" or free
   text), then who this is: owner on THIS laptop (other OS, same hardware),
   owner on ANOTHER machine, or someone else (Step 0 — scope depends on it;
   repo files stay English regardless of the conversation language).
2. Survey the machine read-only; match it against `machines/` (DMI model +
   OS; freshness rule), filter out anything already installed.
3. Present the annotated per-item checklist AS PLAIN TEXT FIRST (every
   tool/app/extension its own line: what it is, why, recommendation for
   this machine) — only then collect the selection (free text and/or the
   multi-select widget as a ticking aid; never a "all/group/item?" mode
   question before the list is shown; subjective look-and-feel is asked,
   never inherited).
4. Apply only what was selected: VERIFY-first, check ASSUMES, confirm each
   system-level change individually, verify after.
5. Finish with the four-list report (applied / already satisfied / skipped /
   no-equivalent) and your own labeled recommendations (Step 5).

If the user is the owner on a new OS/machine, append what was actually done
to SETUP.md per the "grow the manifest" rule in AGENTS.md. If the user is
someone else, offer Step 6: turn what was installed into their own repo
(public/private asked, English content, privacy rule reminded).
