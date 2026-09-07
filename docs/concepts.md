# Concepts

Terminology used throughout monctl's usage docs and command output.

## Screen identifiers

Every screen has three different ids, because no single macOS identifier is reliable in every situation. You can mix and match id types across your setup.

- **Persistent** id is a UUID tied to a display-and-port combination that macOS attempts to keep stable across reboots and sleep, but that can still be reassigned by hotplug race conditions. Recommended for most use cases.
- **Contextual** id is the raw, session-scoped display handle the current WindowServer session assigned; it resets on GPU switches or reboots, but is sometimes more reliable within a single session. If persistent ids keep switching around, try these instead.
- **Serial** id comes from the monitor's own EDID hardware serial number, so it is independent of port, GPU, and session — but useful only if that serial number is actually unique across your monitors, which is not guaranteed on lower-cost displays.

See [Usage](usage.md#screenids-switching) for what to do if ids keep changing on you.

## Origin

`origin` is a pixel coordinate in macOS's shared virtual-desktop space, describing where a screen's top-left corner sits relative to every other screen. The screen set to origin `(0,0)` becomes the primary screen (the one with the white bar in System Preferences).

`monctl set`'s `--right-of`/`--left-of`/`--above`/`--below <id>` flags compute this origin for you from the referenced screen's current bounds — e.g. "to the right of" means the first screen's x-coordinate plus its width. `--origin x,y` remains available directly for placements those flags can't express, such as partial overlap or staggered arrangements.

## Mode

A "mode" is one resolution/refresh-rate/color-depth/scaling combination a screen supports, as printed by `monctl list`. Screens typically support dozens of modes; not all of them are guaranteed to work when selected.

## Scaling and color depth

**Scaling** determines the relationship between a mode's logical resolution (what apps draw to) and the screen's physical pixels. A "scaled" (HiDPI) mode drives more physical pixels than its logical resolution implies, rendering everything sharper at the same apparent size; a "native" (1x) mode maps logical and physical pixels one-to-one. `monctl list` marks each mode as scaled or native — picking a scaled mode on a low-resolution panel can make text and UI elements too large to be useful.

**Color depth** is the number of bits per color channel a mode drives, most commonly 8-bit or 10-bit. Higher bit depths render smoother gradients with less banding, but aren't available on every resolution/refresh-rate combination — a screen may need to drop refresh rate, or you may need a higher-bandwidth cable or port, to unlock its highest color depth.

## Mirroring

A mirroring set is a group of screens all showing the same image. The first screen id in the set is the "Optimize for" screen in System Preferences — resolution choices apply to that screen, and other screens in the set display it scaled to fit.
