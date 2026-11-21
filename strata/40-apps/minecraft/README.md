# Minecraft Stratum

Minecraft runs on two launchers. The official Mojang launcher was removed on 2026-11-21.

| Launcher | Plays | Game folder |
|---|---|---|
| **Horizon Launcher** | Horizon, the Rust reimplementation of Java Edition (main client) | `%APPDATA%\horizon` |
| **Prism Launcher** | Java Edition 26.3 + Fabric, instance `Fabric - Heavily Modded` | `%APPDATA%\PrismLauncher\instances\Fabric - Heavily Modded\minecraft` |
| ~~Official launcher~~ | Uninstalled | Archived to `E:\Minecraft\official-launcher-archive` |

### Current setup (2026-11-21)

- Horizon's `minecraft-dir` is `%APPDATA%\PrismLauncher`, so it prepares its game files from Prism's 26.3 client.
- Prism's `saves`, `resourcepacks` and `shaderpacks` are junctions to Horizon's folders. Both launchers share one copy, so they have to stay on the same Minecraft version.
- The six Arnis worlds (originally 1.21.10) live in the shared `saves`. Opening one in 26.3 upgrades it for good.
- The Xaero maps, mod `config`, `servers.dat` and screenshots from `.minecraft` now live in the Prism instance.
- Your old `options.txt` (keybinds, sensitivity, volumes, render distance, chat, language, active packs) is merged into both clients' `options.txt`; each has a timestamped `.bak` next to it. Prism's Iris uses Complementary Unbound again.
- Horizon built-ins stand in for the old mods: zoom on **C** (Zoomify), minimap (Xaero), dynamic lights (LambDynamicLights), and Complementary Unbound as the shader.
- `%APPDATA%\.minecraft` was a junction to `E:\Minecraft\.minecraft`. The junction is gone, and the real folder, with caches and launcher files deleted, is now `E:\Minecraft\official-launcher-archive`. It holds the original worlds, the Bukkit server (`saves\minecraft`), Distant Horizons, Bobby and Voxy data, and old backups. `arnis-windows.exe` is in `E:\Minecraft`.
- If Arnis offers `.minecraft\saves` for a new world, point it at `%APPDATA%\horizon\saves` instead.

The migration steps below are kept for reference. Before deleting a launcher folder, check it isn't a link: `(Get-Item <path>).LinkType`. Removing a junction removes only the link, and the data stays wherever it points.

## Files

| File | Purpose |
|---|---|
| [`mods.yaml`](mods.yaml) | Every mod, resource pack and shader in the Prism instance, with Modrinth IDs and the Horizon built-ins that replace some of them |

> **Prism launches (fixed 2026-11-21).** Wurst Client, Model Gap Fix and Dynamic Lights are disabled (no 26.3 build on Modrinth), and Sodium/Sodium Extra are pinned to 0.9.2/0.9.5 because the 0.9.3 betas refuse Iris 1.11.7. Don't accept Prism's offer to update those two until a newer Iris is out (see `pinned` in `mods.yaml`).

The Horizon CLI isn't on `PATH`. The commands below call it through a variable:

```powershell
$hz = "$env:LOCALAPPDATA\Programs\Horizon Launcher\horizon-launcher.exe"
```

---

## Moving off the official launcher

Copy, never move. Horizon is a nightly build, and opening a world in a newer game version upgrades it for good. Keep the originals until each world opens correctly in its new home.

### What's in `.minecraft` and where it goes

| Item | Size | Destination |
|---|---|---|
| `saves\Arnis World 1` … `6` | ~3.3 GB | Horizon `saves\` (and Prism, see below) |
| `saves\minecraft` | 5.6 GB | **Not a world.** A Bukkit server folder. Move it to its own server folder or archive it |
| `screenshots\` | 224 MB | Prism `screenshots\` or an archive |
| `resourcepacks\`, `shaderpacks\` | small | Skip. Prism already has the newer 26.3 versions |
| `mods\` | — | Skip. Old 1.21.10 copies of the Prism mods |
| `options.txt` | — | Horizon and Prism (step 3) |
| `servers.dat` | — | Prism (step 3). Horizon has its own list |
| `xaero\`, `XaeroWaypoints_BACKUP*` | 673 MB | Prism instance folder, for your old maps and waypoints |
| `config\` | 2 MB | Prism instance folder (mod settings; Prism's instance has none yet) |
| `Distant_Horizons_server_data\` | 3.7 GB | Archive or drop. Distant Horizons isn't in the Prism pack any more |
| `backups\`, `wurst\` | 170 MB | Archive |
| `launcher_*`, `*.bin`, `profilekeys\` | — | **Never copy.** Official launcher accounts and credentials. Horizon and Prism sign in on their own |

### 1. Back up

```powershell
robocopy "$env:APPDATA\.minecraft" "D:\Backups\minecraft-official" /E /XF launcher_*.json *.bin /XD profilekeys versions libraries assets webcache webcache2
```

### 2. Stop Horizon depending on `.minecraft`

Horizon's `minecraft-dir` setting points at `.minecraft`, and Horizon prepares its game files from there. Point it at Prism, which has the 26.3 client in its `libraries\`. Then prepare again and launch once to check:

```powershell
& $hz settings minecraft-dir "$env:APPDATA\PrismLauncher"
```

```powershell
& $hz prepare
```

If `prepare` can't find the files, there are two fallbacks. `& $hz prepare --minecraft "<folder>"` points it at a specific game folder. `& $hz prepare --download` fetches the files from Mojang with your signed-in account.

### 3. Carry your settings and data over

**Into Horizon:**

- **Options**: Horizon's `options.txt` uses the same keys as Java Edition (all 61 keybinds match), so your settings carry over. Back up `%APPDATA%\horizon\options.txt` first, then copy `.minecraft\options.txt` over it.
- **Worlds**: copy each `Arnis World N` folder into `%APPDATA%\horizon\saves\`, then open it in Horizon.
- **Resource packs**: copy from the Prism instance's `resourcepacks\` into `%APPDATA%\horizon\resourcepacks\`, or share the folder (see step 4). It hasn't been checked whether Fresh Animations works in Horizon, because it relies on the EMF/ETF mods.
- **Servers**: add them in the game's Multiplayer screen or with `& $hz multiplayer add <address> --name "<name>"`.
- **Mods**: Horizon has zoom, fullbright, dynamic lights, minimap, entity culling and LOD distance built in (the `horizon_builtin` entries in `mods.yaml`). It can also carry some Java mods over:
  - `& $hz modpack import "$env:APPDATA\PrismLauncher\instances\Fabric - Heavily Modded"` reads the whole pack and writes a coverage report of what Horizon can run.
  - `& $hz mods check <modrinth-id>` checks a single mod.

**Into Prism** (same game, so everything copies as-is):

```powershell
$old = "$env:APPDATA\.minecraft"
$prism = "$env:APPDATA\PrismLauncher\instances\Fabric - Heavily Modded\minecraft"
robocopy "$old\config" "$prism\config" /E /XC /XN /XO
robocopy "$old\xaero" "$prism\xaero" /E /XC /XN /XO
Copy-Item "$old\servers.dat" "$prism\servers.dat" -WhatIf
```

The `/XC /XN /XO` flags make robocopy skip any file that already exists in Prism. Remove `-WhatIf` to copy `servers.dat`.

### 4. Keep Prism in sync

Choose one of these.

**A. Share folders** (one copy on disk, both launchers see it). **In use since 2026-11-21 for `resourcepacks`, `shaderpacks` and `saves`.** Turn the Prism instance's folders into junctions pointing at Horizon's. A junction needs no admin rights. Prism's folder has to be empty or moved aside first:

```powershell
$prism = "$env:APPDATA\PrismLauncher\instances\Fabric - Heavily Modded\minecraft"
$horizon = "$env:APPDATA\horizon"
foreach ($dir in 'resourcepacks', 'shaderpacks') {   # add 'saves' only if you accept the risk below
  New-Item -ItemType Directory -Force "$horizon\$dir" -WhatIf | Out-Null
  if (Test-Path "$prism\$dir") { Rename-Item "$prism\$dir" "$dir.bak" -WhatIf }
  New-Item -ItemType Junction -Path "$prism\$dir" -Target "$horizon\$dir" -WhatIf
}
```

Remove `-WhatIf` to apply it, then move the contents of each `*.bak` folder into Horizon's folder. Use `Move-Item -LiteralPath` for that, otherwise a file like `[1.6] Enhanced Boss Bars.zip` is read as a wildcard and silently skipped.

- **Sharing `saves`** works only while both clients play the same Minecraft version (26.3 now). Whichever client updates first upgrades the shared worlds, and the other may refuse to open them. Keep backups if you add it.
- **Deleting the Prism instance** can delete through the junctions and take Horizon's folders with it. Remove the junctions first: `Remove-Item` on the junction itself, without `-Recurse`.

**B. Let Horizon launch the Prism pack too.** Horizon can copy the Prism instance into a Java instance of its own, so one launcher starts both clients:

```powershell
& $hz instance copy-from "Fabric - Heavily Modded"
```

This is a copy: the Prism instance stays as it is, but the two copies drift apart afterwards.

### 5. Remove the official launcher

1. Uninstall **Minecraft Launcher** from *Settings → Apps → Installed apps*.
2. Rename `%APPDATA%\.minecraft` to `.minecraft.old` and keep it for a couple of weeks.
3. Once Horizon and Prism both start and every world has opened, delete `.minecraft.old`.
