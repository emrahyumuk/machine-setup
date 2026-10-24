hardware: thinkpad-p14s
model: ThinkPad P14s Gen 6 AMD
os: windows
hostname: MRA-WINDOWS
role: secondary
layers: SETUP.md §1 (git, mpv), §2b (Windows — first session 2026-10-24), §3a translated (charge limit → Lenovo Vantage 75/80, Fast Startup off, BIOS via USB because the ESP is too small for Lenovo's Windows tool too, WebHID → Chrome, UMA is a BIOS item)
inventory: inventory/thinkpad-p14s-windows/
scripts: os/windows/  (bootstrap.ps1 / verify.ps1 / collect.ps1)
last-applied: 2026-10-24
last-collected: 2026-10-24
last-verified: never
notes: The factory Windows 11 Pro 25H2 in the ~95 GB dual-boot slice (hardware/thinkpad-p14s.md). Occasional-use slice — no Rust, no agent CLIs, no ~/.claude sync on purpose (SETUP.md §2b "Deliberately not done here"). Chrome is the default browser here.
