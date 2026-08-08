# Hardware — what's on the desk

The physical layer of this setup. Everything else in this repo assumes (or
works around) the items below; software notes for each live in SETUP.md.

## Computer

| Item | Model | Notes |
|------|-------|-------|
| Laptop | Lenovo ThinkPad P14s Gen 6 AMD (21QMS1BQ00) | Ryzen AI 7 PRO 350 (8c/16t), Radeon 860M iGPU, XDNA2 NPU (58 TOPS), 24 GB RAM (shared with iGPU — the binding constraint for local LLMs), LUKS btrfs. Charge limit capped via Battery Health Charging extension (APPS.md). |

## Peripherals

| Item | Model | Connection | Notes |
|------|-------|------------|-------|
| Mouse | Logitech MX Master 3S | Bluetooth (HID++, no receiver) | Configured with Solaar (APPS.md); DPI/SmartShift stored on the device itself. |
| DAC/amp | Qudelix 5K | USB for config, Bluetooth for audio | WebHID config app needs USB, not BT — full story incl. udev rule in SETUP.md §3. |
| Keyboard | Keychron B6 | Wireless | |
| Monitor | Dell P2725QE | USB-C | 27" 4K USB-C hub monitor (power delivery + ports over one cable). |
| Wired headphones | Superlux HD681 | 3.5 mm into the Qudelix 5K | Semi-open — the reason the Qudelix exists in this chain. |
| Wireless earbuds | Soundcore Liberty 4 Pro | Bluetooth | |

## Around the desk

| Item | Model | Notes |
|------|-------|-------|
| Phone | Motorola Edge 70 | Paired via GSConnect (pairing is per-machine state, re-pair on a new install). Charge limit 80%. |

Not bought yet: desk speakers, chair — rows land here when they do.
