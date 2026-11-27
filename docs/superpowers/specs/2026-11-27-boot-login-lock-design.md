# Boot, login, lock and splash screens (design)

Date: 2026-11-27. The user chose "contours everywhere".

## Intent

The screens around the desktop should match it: the OLED Span contours (thin grey lines on black)
wherever a picture can go, and black with a thin grey spinner where only simple graphics work. No
logos.

## Decided

| Screen | Look | How | Who runs it |
|---|---|---|---|
| Laptop lock screen | The live OLED Span wallpaper (animated) | `kscreenlockerrc [Greeter] WallpaperPlugin=com.csps.oledspan`, with the top-panel dimming off | Claude (user config) |
| Laptop splash after login | Contours still, a thin grey spinner, fading into the desktop | A splash-only look-and-feel package `org.csps.oledspan.splash` in `~/.local/share/plasma/look-and-feel/`, set in `ksplashrc` | Claude |
| Laptop login (SDDM) | Contours still behind Breeze's login form | Image in `/usr/share/wallpapers/`, plus Breeze's `theme.conf.user` | The user (sudo); commands in the repo |
| Laptop boot splash | Black, thin grey spinner | A Plymouth script theme `oled-span`, then `plymouth-set-default-theme -R` (rebuilds the initramfs) | The user (sudo) |
| Laptop boot menu | Unchanged | systemd-boot has no themes; `loader.conf` only sets the timeout and resolution | — (documented) |
| Windows lock and sign-in | Contours still | The WinRT `LockScreen.SetImageFileAsync` from Windows PowerShell 5.1; the sign-in screen already shows the lock picture | Claude (user setting) |
| Windows boot logo, sign-out and shutdown | Unchanged | Firmware logo or system screens; not customisable without hacks | — (documented) |

## Stills

- Rendered from the web build (`wallpaper-engine-web/index.html?style=contours&topdim=0`) with
  headless Brave at 1920x1080, which is both main screens.
- Kept in `strata/40-apps/oled-span/stills/`.
- `render-stills.ps1` makes them again.

## Constraints

- Back up every config file before changing it.
- The sudo steps are files plus exact commands; Claude never runs sudo.
- Nothing is committed unless the user asks.
- Test with the tools' own test modes (`kscreenlocker_greet --testing`, `ksplashqml --test`,
  `sddm-greeter-qt6 --test-mode`) instead of locking or logging out the live session.
