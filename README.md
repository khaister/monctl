# monctl

macOS command line utility to configure multi-display resolutions and arrangements. Essentially XRandR for macOS.

> [!NOTE]
> `monctl` is a fork of [displayplacer](https://github.com/jakehilborn/displayplacer) by Jake Hilborn, being renamed and modernized. If you just want the original, stable, published tool, `brew install displayplacer` or visit its [releases](https://github.com/jakehilborn/displayplacer/releases) tab — all credit for the original design and implementation goes to that project.

## Download

Build from source:

```sh
git clone https://github.com/khaister/monctl.git
cd monctl
swift build -c release
sudo cp .build/release/monctl /usr/local/bin/monctl
```

## Usage

Show current screen info and possible resolutions:

```sh
monctl list
```

Apply screen config (`hz` & `color_depth` are optional):

```sh
monctl "id:<screenId> res:<width>x<height> hz:<num> color_depth:<num> scaling:<on/off> origin:(<x>,<y>) degree:<0/90/180/270>"
```

Apply screen config using a mode number instead of resolution:

```sh
monctl "id:<screenId> mode:<modeNum> origin:(<x>,<y>) degree:<0/90/180/270>"
```

Apply screen config with mirrored screens:

```sh
monctl "id:<mainScreenId>+<1stMirrorScreenId>+<2ndMirrorScreenId> res:<width>x<height> scaling:<on/off> origin:(<x>,<y>) degree:<0/90/180/270>"
```

Silence errors per-screen using `quiet`:

```sh
monctl "id:<screenId> mode:<modeNum> origin:(<x>,<y>) degree:0 quiet:true"
```

Disable a screen:

```sh
monctl "id:<screenId> enabled:false"
```

## Instructions

1. Manually set rotations 1st, resolutions 2nd, and arrangement 3rd. For extra resolutions and rotations, see [Notes](#notes) below.
   - Open System Preferences -> Displays
   - Choose desired screen rotations (use `monctl` for rotating the internal MacBook screen)
   - Choose desired resolutions (use `monctl` for extra resolutions)
   - Drag the white bar to your desired primary screen
   - Arrange screens as desired and/or enable mirroring. To enable partial mirroring, hold the alt/option key and drag a display on top of another.
2. Use `monctl list` to print your current layout's args, so you can create profiles for scripting/hotkeys with [Automator](https://github.com/jakehilborn/displayplacer/issues/13), BetterTouchTool, etc.

> [!NOTE]
> `monctl list` and System Preferences only show resolutions for the screen's *current* rotation.

## ScreenIds Switching

> [!WARNING]
> macOS sometimes changes persistent screenIds when there are race conditions from external screens waking up in non-deterministic order. If none of the screenId options below work for your setup, search displayplacer's GitHub Issues for conversation on this — it's inherited, upstream behavior, so the existing discussions still apply. Many people have written shell scripts to work around this. Recommended discussions: https://github.com/jakehilborn/displayplacer/issues/80, https://github.com/jakehilborn/displayplacer/issues/30, https://github.com/jakehilborn/displayplacer/issues/89, https://github.com/jakehilborn/displayplacer/issues/77, https://github.com/jakehilborn/displayplacer/issues/100, https://github.com/jakehilborn/displayplacer/pull/96.

You can mix and match screenId types across your setup:

- **Persistent** screenIds usually stay the same. Recommended for most use cases.
- **Contextual** screenIds change when switching GPUs or when cables switch ports. If persistent screenIds keep switching around, try these instead.
- **Serial** screenIds are tied to your display hardware. Use these if they're unique across all your monitors.

## Notes

- Use an extra resolution shown in `monctl list` by executing:
  ```sh
  monctl "id:<screenId> mode:<modeNum>"
  ```
  Some listed resolutions do not work — if you select one, `monctl` will default to another working resolution.
- Rotate your internal MacBook screen:
  ```sh
  monctl "id:<screenId> degree:<0/90/180/270>"
  ```
- The screen set to origin `(0,0)` becomes the primary screen (white bar in System Preferences).
- The first screenId in a mirroring set is the "Optimize for" screen in System Preferences — you can only choose resolutions for that screen. If a mirroring resolution you need is missing, try making a different screenId first in the set.
- `hz` and `color_depth` are optional. If omitted, the highest hz and then the highest color depth are applied automatically.
- `screenId` is optional if there's only one screen — but `monctl` generally expects the full profile per screen, so this may be buggy.

> [!TIP]
> If you disable a screen, you may need to unplug/replug it to bring it back. On some setups you can re-enable it instead:
> ```sh
> monctl "id:<screenId> enabled:true"
> ```
