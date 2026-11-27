# OLED Span around the desktop (laptop)

The screens before and after the desktop, in the same look: the contours where a picture can go,
black with a thin grey spinner where only simple graphics work, no logos.

| Screen | Look | Set up with | Needs |
|---|---|---|---|
| Lock screen | The live OLED Span wallpaper, moving, with no blur behind the password form | `install-kde-screens.sh --lock`, then [`lockscreen/`](lockscreen/) for the blur | the wallpaper plugin (`../install-kde.sh --apply`); sudo for the blur |
| Splash after login | The contours still, thin grey spinner; the desktop fades in over it | `install-kde-screens.sh --splash` | — |
| Login screen (SDDM) | Breeze with the contours still and a `23:49` / `2026-11-27` clock (theme `oled-span`) | [`sddm/install-sddm-theme.sh`](sddm/install-sddm-theme.sh) | sudo |
| Boot splash (Plymouth) | Black, thin grey spinner (password prompt in grey if a disk is encrypted) | [`plymouth/oled-span/`](plymouth/oled-span/), commands below | sudo |
| Boot menu (systemd-boot) | Unchanged | — | — |

The still is `../stills/contours-1920x1080.png`, made by `../render-still.py` (a NumPy port of the
shader's contours style). Make a new one with `python3 ../render-still.py --time <seconds>`; the time
picks the pattern.

## No blur on the lock screen (sudo)

While the password form shows, KDE's lock screen blurs the wallpaper and lifts its blacks to grey
(Breeze's `WallpaperFader`). The lock screen QML belongs to `plasma-desktop`
(`/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml`), and only
test mode can choose another, so the fix patches that file:
- [`lockscreen/oled-lockscreen-noblur`](lockscreen/oled-lockscreen-noblur) replaces the line that
  gives the fader its source with `visible: false`. The fader then draws nothing, and its states
  still fade the form in and out. The original file is kept in `/var/lib/csps-stratum/`.
- A pacman hook ([`oled-lockscreen-noblur.hook`](lockscreen/oled-lockscreen-noblur.hook)) runs it
  again after every `plasma-desktop` install or upgrade. If Breeze changes that line, it only prints
  a warning and never fails the update.

```sh
cd ~/REPOS/csps-stratum
strata/40-apps/oled-span/kde-screens/lockscreen/install-lockscreen-noblur.sh --dry-run
sudo strata/40-apps/oled-span/kde-screens/lockscreen/install-lockscreen-noblur.sh
sudo strata/40-apps/oled-span/kde-screens/lockscreen/install-lockscreen-noblur.sh --undo   # blur back, hook removed
```

Check it by locking (Meta+L) and moving the mouse: the contours stay sharp and black behind the
form. The test mode (`kscreenlocker_greet --testing`) starts with the form hidden, so it can't show
the blur.

## Lock screen and splash (no sudo)

```sh
cd ~/REPOS/csps-stratum && git pull --ff-only
strata/40-apps/oled-span/kde-screens/install-kde-screens.sh --dry-run --lock --splash   # preview
strata/40-apps/oled-span/kde-screens/install-kde-screens.sh --lock --splash
```

- `--lock` backs up `~/.config/kscreenlockerrc` and sets the lock screen wallpaper to OLED Span, with
  the top-bar dimming and the pausing turned off.
- `--splash` installs the splash package `org.csps.oledspan.splash` (the still is added at install
  time) and backs up `~/.config/ksplashrc`. In System Settings it also appears as a Global Theme. Pick
  it under **Splash Screen** only; as a Global Theme it has nothing else.
- To preview without logging out, run `ksplashqml org.csps.oledspan.splash --test` and
  `/usr/lib/kscreenlocker_greet --testing` (close it with `pkill -f kscreenlocker_greet`).
- To undo, copy the `.bak` files back, or choose in System Settings: **Splash Screen → Breeze**, and
  **Screen Locking → Appearance → Image**.

## Login screen (SDDM, sudo)

The login screen uses its own theme, `oled-span`:
- a copy of the installed Breeze login theme;
- the contours picture behind the form;
- its clock fixed to `23:49` and `2026-11-27` ([`sddm/OledClock.qml`](sddm/OledClock.qml)), like
  the top bar;
- no blur ([`sddm/OledFader.qml`](sddm/OledFader.qml)). While the form shows, Breeze's
  `WallpaperFader` blurs the picture and lifts its blacks to a grey haze; this copy keeps only its
  fading of the form, so the contours stay sharp and black.

The locale can't set the format here, because the SDDM greeter ignores `LC_TIME`: with
`GreeterEnvironment=...,LC_TIME=hu_HU.UTF-8` it still showed `Friday 27 November 2026`.

```sh
cd ~/REPOS/csps-stratum
strata/40-apps/oled-span/kde-screens/sddm/install-sddm-theme.sh --build-to /tmp/oled-span-preview   # no sudo
sddm-greeter-qt6 --test-mode --theme /tmp/oled-span-preview   # preview in a window; close it when done
sudo strata/40-apps/oled-span/kde-screens/sddm/install-sddm-theme.sh   # install and make it current
```

- The script copies the picture to `/usr/share/wallpapers/oled-span-contours.png` and builds
  `/usr/share/sddm/themes/oled-span`.
- It backs up `/etc/sddm.conf.d/kde_settings.conf` and sets `Current=oled-span`.
- It refuses to run if Breeze's `Main.qml` no longer has exactly one `Clock {` and one
  `WallpaperFader {` line to replace.
- Run it again after a Plasma update, so the copy picks up Breeze's changes.
- Undo: set `Current=breeze` in that file (with sudo), or copy its `.bak` back.

## Time format

The lock screen, the login splash and KDE apps show times and dates in the session's `LC_TIME`:
Hungarian (`hu_HU.UTF-8`), so 24-hour time and year-first dates (`2026. 11. 27.`). It is set in
System Settings → Region & Language → Time.

Don't export `LC_ALL` in `~/.zshenv`. SDDM starts Plasma through the login shell, which reads
`~/.zshenv`, so `LC_ALL` there overrides every Plasma format; the lock screen then showed
`11:35 PM`. US formats for terminals belong in `~/.zshrc`
([`strata/20-shell/zsh/.zshrc`](../../../20-shell/zsh/.zshrc)).

## Boot splash (Plymouth, sudo)

> **Don't use this theme yet.** On 2026-11-27 the laptop then booted to a black screen with
> `linux` 7.3.5: no text console, no journal, and Esc did nothing. The backup kernel
> (`linux-lts` 6.18.64), built with the same theme, booted fine. Going back to `bgrt` fixed it:
> boot the backup kernel from the systemd-boot menu (tap Space at power-on), then run
> `sudo plymouth-set-default-theme -R bgrt`. The cause isn't known yet; test any change on the
> backup kernel first.

```sh
cd ~/REPOS/csps-stratum
sudo cp -r strata/40-apps/oled-span/kde-screens/plymouth/oled-span /usr/share/plymouth/themes/
sudo plymouth-set-default-theme -R oled-span   # sets it and rebuilds the initramfs (mkinitcpio -P)
```

- The kernel line already has `quiet splash`, and `plymouth` is in the mkinitcpio `HOOKS`, so nothing
  else changes.
- To preview it before rebooting, switch to a text console (Ctrl+Alt+F3), log in and run
  `sudo plymouthd; sudo plymouth --show-splash; sleep 5; sudo plymouth --quit`. Then go back with
  Ctrl+Alt+F1 (or F2).
- To undo: `sudo plymouth-set-default-theme -R bgrt` (the old theme: the laptop maker's logo with a
  spinner).

## Boot menu

The laptop boots with systemd-boot, whose menu is plain UEFI text with no themes. Only
`/boot/loader/loader.conf` changes it:
- `timeout 0` skips the menu; hold Space while booting to see it.
- `console-mode max` uses the largest text mode.

GRUB would allow a themed menu, but switching boot loaders isn't worth the risk for a menu that is
normally skipped.

## Logout screen

The logout screen is KDE's own (the Breeze Dark global theme) and already uses the OLED Monochrome
colours and Plasma style. It has no picture to change.
