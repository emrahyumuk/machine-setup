hardware: mbp14
model: MacBook Pro (Mac14,9)
os: macos
hostname: mra-mac
role: secondary — always-on home server + desk machine (remote via SSH / Screen Sharing / Tailscale, iOS simulator testing, overflow compute for agents; also used at its own desk with monitor, keyboard and mouse)
layers: SETUP.md §1, §2c (macOS), §3b (MacBook Pro 14" M2 Pro), §4
inventory: inventory/mbp14-macos/
scripts: os/macos/{bootstrap,verify,collect,update-check}.sh
last-applied: 2026-10-18
last-collected: 2026-10-18
last-verified: 2026-10-18
notes: macOS Tahoe 26.6.2 at setup. First session 2026-09-06 configured the machine, but its manifest text and scripts never reached the repo; the 2026-10-18 session reconstructed §2c/§3b from the scripts it left in ~/.local/bin, re-verified every item, and completed the server role. Stays on macOS 26.x until 27.1 (SETUP.md §2c "Update cadence").
