# Hardware — machines and the desk

The physical layer. One file per machine under `hardware/`, one record per
(machine, OS) under `machines/`; this page is the index plus the shared desk.

## Machines

| Short name | Machine | OSes (see `machines/`) | Details |
|------------|---------|------------------------|---------|
| `thinkpad-p14s` | Lenovo ThinkPad P14s Gen 6 AMD | fedora (primary), windows (dual-boot slice, not yet set up) | [hardware/thinkpad-p14s.md](hardware/thinkpad-p14s.md) |

Naming: `<hardware>-<os>` everywhere (machine records, inventory dirs,
suggested hostnames). The short name comes from the model, not the owner.

## Peripherals

| Item | Model | Connection | Notes |
|------|-------|------------|-------|
| Mouse | Logitech MX Master 3S Wireless Mouse | Bluetooth (HID++, no receiver) | Configured with Solaar (APPS.md); DPI/SmartShift stored on the device itself. |
| DAC/amp | Qudelix-5K Bluetooth USB DAC/AMP | USB for config, Bluetooth for audio | WebHID config app needs USB, not BT — full story incl. udev rule in SETUP.md §3. |
| Keyboard | Keychron B6 Pro Ultra-Slim Wireless Keyboard | Wireless | |
| Monitor | Dell Pro 27 Plus 4K USB-C Hub Monitor (P2725QE) | USB-C | Power delivery + ports over one cable. |
| Wired headphones | Superlux HD681 Semi-Open Headphones | 3.5 mm into the Qudelix-5K | Semi-open — the reason the Qudelix exists in this chain. |
| Wireless earbuds | Anker Soundcore Liberty 4 Pro | Bluetooth | |

## Around the desk

| Item | Model | Notes |
|------|-------|-------|
| Phone | Motorola Edge 70 | Paired via GSConnect (pairing is per-machine state, re-pair on a new install). Charge limit 80%. |
| Backpack | Case Logic Jaunt 15.6" Laptop Backpack | Carries the ThinkPad. |
| Tracker | Xiaomi Smart Tag | In the backpack — Google Find My Device network. |

Not bought yet:

- **Chair** — decided: IKEA MARKUS.
- **Mouse pad** — decided: 40×90 cm custom print of the mRA Labs lockup
  (print-ready file lives in the private brand assets).
- **Small desk speaker** — considering; the ThinkPad speakers are quiet by
  hardware and that verdict is final (the DSP-boost attempt is a tombstone in
  SETUP.md §3), so more loudness means external hardware.
