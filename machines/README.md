# machines/ — one record per (hardware, OS) pair

File name = `<hardware>-<os>.md`: the hardware short name from
`hardware/<hardware>.md` + the OS. Agents match a machine by the `model:`
line (DMI product name, read automatically) + `os:`; `hostname:` only breaks
ties. Never store identity here — no serial numbers, MACs, keys.

Fields:

- `hardware:` short name → `hardware/<name>.md`
- `model:` DMI product name, as the machine reports it
- `os:` fedora | windows | macos | ubuntu …
- `hostname:` the static hostname set on day one (SETUP.md hostname trap)
- `role:` primary (the machine the owner lives on — its layer is the
  freshest and the reference for DECISIONS) | secondary
- `layers:` which SETUP.md sections apply on this machine
- `last-applied:` last bootstrap/setup run (stamped by `os/<os>/bootstrap`)
- `last-collected:` last inventory refresh (stamped by `os/<os>/collect`)
- `last-verified:` last time `os/<os>/verify` passed clean (stamped by collect)

Freshness rule for agents (AGENTS.md Step 1): a layer whose `last-verified`
is older than 90 days is treated as a CACHE of mechanics, not as truth —
re-verify each item, re-check package ids/paths against current sources,
and carry over any DECISION that the primary machine's layer has and this
one lacks. Staleness is meant to be visible here, not hidden.
