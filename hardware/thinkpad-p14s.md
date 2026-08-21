# ThinkPad P14s Gen 6 AMD (`thinkpad-p14s`)

The reference machine. Hosts two OSes (see `machines/`): Fedora (primary)
and the factory Windows in a dual-boot slice. Software notes live in
SETUP.md §3a; peripherals and the desk are in HARDWARE.md (shared across
machines).

## Computer

| Item | Model | Notes |
|------|-------|-------|
| Laptop | Lenovo ThinkPad P14s Gen 6 AMD (21QMS1BQ00) | Ryzen AI 7 PRO 350 (8c/16t), Radeon 860M iGPU, XDNA2 NPU (58 TOPS), 32 GB RAM — of which 4 GB is a BIOS UMA carve-out for the iGPU, so the OS sees ~27 GB (was 8 GB until 2026-08-20; halved after a week of OOM storms — see SETUP.md). 512 GB NVMe, **dual boot**: the Windows it shipped with stays in a ~95 GB NTFS slice (firmware boot order puts Fedora first), Fedora owns the rest as LUKS btrfs (379 GB). Because Windows is still there the RTC runs in LOCAL time (Anaconda does this when it detects Windows) so both OSes agree on the clock; `timedatectl` warns about DST with that mode, moot in Türkiye (no DST). Charge limit capped via Battery Health Charging extension (APPS.md). |
