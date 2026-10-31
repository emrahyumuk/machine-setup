hardware: thinkpad-p14s
model: ThinkPad P14s Gen 6 AMD
os: windows
hostname: MRA-WINDOWS
role: secondary
layers: SETUP.md §1 (git, mpv), §2b (Windows — first session 2026-10-24), §3a translated (charge limit → Lenovo Vantage 75/80, Fast Startup off, BIOS via the Windows tool with a FAT32 USB key plugged in (it stages the capsule there; the ESP is too small), WebHID → Chrome, UMA is a BIOS item)
inventory: inventory/thinkpad-p14s-windows/
scripts: os/windows/  (bootstrap.ps1 / verify.ps1 / collect.ps1)
last-applied: 2026-10-24
last-collected: 2026-10-25
last-verified: never
notes: The factory Windows 11 Pro (26H2 since 2026-10-25) in the ~95 GB dual-boot slice (hardware/thinkpad-p14s.md). Occasional-use slice + Windows release builds of Tauri apps (Rust/MSVC, Smart App Control OFF) — no agent CLIs, no ~/.claude sync on purpose (SETUP.md §2b "Deliberately not done here"). Chrome is the default browser here.
pending: Fixes from the 2026-10-25 review were written on Fedora and never run on Windows. At the next Windows session: `git switch main; git pull; git branch -D windows-port`; create a repo-root `.collect-exclude` (empty is valid) or collect.ps1 stops; run verify.ps1 (sets last-verified); in upall, decline the UAC prompt once and run it twice in a row; re-run bootstrap.ps1; confirm `-Debloat` refuses under pwsh; run collect.ps1. Delete this line once they pass.
