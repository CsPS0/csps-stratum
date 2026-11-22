# Custom Windhawk mods

Two local mods that aren't in the Windhawk catalog. Both run inside Explorer and build with
Windhawk's bundled clang: they compile with `-Wall` and no warnings, and link into a DLL with the
libraries in their `@compilerOptions`.

| Mod | What it does |
|---|---|
| [`taskbar-pin-layout.wh.cpp`](taskbar-pin-layout.wh.cpp) | Fills the taskbar like a macOS dock: pins a list of apps in a fixed order. |
| [`taskbar-trailing-separator.wh.cpp`](taskbar-trailing-separator.wh.cpp) | Like the macOS Dock: the last separator (pinned \| running) only shows while an app that isn't pinned is open. Hidden, it keeps its layout slot (opacity 0, a negative right margin of its own width), so the mod can still tell from the buttons' positions what comes after it. It doesn't use `ItemsRepeater`'s index API: Windhawk's headers are WinUI 3 and the taskbar's list is WinUI 2. |
| [`taskbar-attention-bounce.wh.cpp`](taskbar-attention-bounce.wh.cpp) | Makes an app's icon keep hopping, like on the macOS Dock, while the app asks for attention. That's the state Windows normally shows as an orange button. It stops once you switch to the app. |

## Why `taskbar-pin-layout` is a mod

Windows 11 only lets Explorer itself pin or reorder taskbar apps. When a script calls the
private PinManager from outside Explorer, pinning returns `E_ACCESSDENIED`, and the reorder
call returns success but changes nothing. The mod makes the same calls from inside Explorer,
the way "Taskbar Icon Separators" does.

- **When it applies:** once, and again only when the list changes. A hash of the list is kept
  in the mod's storage, so apps you unpin by hand stay unpinned. To force a re-apply, turn on
  **Apply again**, save, then turn it off.
- **Pins not in the list** keep their order after the listed ones. The Taskbar Icon Separators
  separator is one of these, which keeps it at the end of the pinned apps.
- **How apps are matched:** by the program each pinned shortcut starts, because Windows renames
  the pinned shortcuts (`Brave (10).lnk`) whenever it rewrites a pin. If an app's install folder
  is versioned (Figma, Roblox), it falls back to the program's file name, but only when exactly
  one pin has it.
- **Groups:** `separator` entries are slots for "Taskbar Icon Separators" separators, filled in the
  order the separators were added (add them from the taskbar's right-click menu first). The list
  groups the dock as general use | chat and media | development | gaming | customizing and system,
  with the last separator between pinned and running apps.
- **Windhawk keeps a mod's saved settings across updates**, so each change of the default list
  renames the setting (`pins` → `apps` in 1.3 → `layout` in 1.4) to make the new default take effect.
- **Which apps are listed:** only apps that were already on the taskbar or pinned in Start.
  Disk Cleanup, Superposition and Wintoys were left off. Wallpaper Engine is pinned by its
  `launcher.exe`, because its Start entry is a Steam URL.

## Why `taskbar-attention-bounce` doesn't clash with Taskbar Dock Animation

- It hooks `TaskListButton::UpdateVisualStates` and watches the icon panel's
  `RunningIndicatorStates` group for `RequestingAttentionRunningIndicator`.
- It animates the icon's composition `Translation.Y`. Taskbar Dock Animation uses the icon's
  `RenderTransform` for magnification, so each mod has its own transform.

## Install

1. Windhawk → **Create a new mod** (the `+` button).
2. Replace the template with the file's contents.
3. Click **Compile mod**, then **Exit editing mode**.

To copy a file to the clipboard:

```powershell
Get-Content strata\40-apps\windhawk\custom-mods\taskbar-pin-layout.wh.cpp -Raw | Set-Clipboard
```

## Build check without Windhawk's editor

Compile and link to a throwaway DLL, passing the libraries listed in the mod's `@compilerOptions`
(a syntax-only check misses a missing library):

```powershell
$C = "C:\Program Files\Windhawk\Compiler"
& "$C\bin\clang++.exe" "@$C\compile_flags.txt" "-I$C\include" -shared -o $env:TEMP\check.dll strata\40-apps\windhawk\custom-mods\taskbar-pin-layout.wh.cpp -lole32 -loleaut32 -lshell32 -lshlwapi
```
