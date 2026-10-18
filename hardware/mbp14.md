# MacBook Pro 14" M2 Pro (`mbp14`)

Second machine. One OS (macOS, see `machines/mbp14-macos.md`). Role: an
always-on home server that is also a desk machine — it sits on its own desk
with a monitor, keyboard and mouse, mostly reached over SSH / Screen Sharing
from the ThinkPad on the same home network (Tailscale when away). Software
notes live in SETUP.md §3b; shared desk peripherals are in HARDWARE.md.

## Computer

| Item | Model | Notes |
|------|-------|-------|
| Laptop | Apple MacBook Pro 14" 2023 (Mac14,9) | Apple M2 Pro (6P + 4E cores, 16-core GPU), 16 GB unified memory, 512 GB SSD (APFS, FileVault on). Permanently on AC → macOS charge limit 80% (Settings → Battery → Charging). No `autorestart` knob on Apple Silicon (SETUP.md §3b); the battery rides through short outages. |

## Peripherals at this desk

| Item | Model | Connection | Notes |
|------|-------|------------|-------|
| Mouse | Apple Magic Mouse | Bluetooth | Secondary click had to be switched on (`MouseButtonMode=TwoButton`) — off by default; SETUP.md §3b. No Logi Options+ here (the MX Master lives at the ThinkPad desk). |
| Keyboard | Apple Magic Keyboard | Bluetooth | |
| Monitor | (desk monitor — model to be recorded) | | |
