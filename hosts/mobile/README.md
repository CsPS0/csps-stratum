# Mobile Profile (`hosts/mobile`)

Hardware and application specifications for the **Samsung Galaxy A52s 5G** running Android 14 (One UI 6.1).

---

## Hardware & System Specifications

- **Device**: Samsung Galaxy A52s 5G (`SM-A528B`, `a52sxq`)
- **SoC**: Qualcomm Snapdragon 778G 5G (`SM7325`, `arm64-v8a`)
- **Display**: 1080×2400 AMOLED 120Hz | Physical: 450 DPI | **Override Density: 392 DPI** (~440dp width)
- **Terminal**: Termux (`com.termux`) with stock bash environment (no custom dotfiles or prompt themes)
- **Custom Client**: Aliucord with `rain.json` Dracula Dark theme and 19 plugins (tracked in `strata/40-apps/aliucord/`)
- **File Sharing**: LocalSend (cross-device sharing with desktop)

---

## Tracked Assets

- `profile.yaml`: Device hardware, display metrics, and software specifications.
- `packages.txt`: Exported inventory of packages installed via Termux `pkg`.
- `software-inventory.md`: Complete catalogue of mobile companion apps, dev tools, and Good Lock modules.
