<a href="#"><img align="right" src="animation.gif"></a>

## monctl
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/firstcontributions/first-contributions)  
macOS command line utility to configure multi-display resolutions and arrangements. Essentially XRandR for macOS.

`monctl` is a fork of [displayplacer](https://github.com/jakehilborn/displayplacer) by Jake Hilborn, being renamed and modernized. If you just want the original, stable, published tool, `brew install displayplacer` or visit its [releases](https://github.com/jakehilborn/displayplacer/releases) tab - all credit for the original design and implementation goes to that project.

#### Download:

Build from source: clone this repo, then `cd src && make && make install`.

#### Usage:

Show current screen info and possible resolutions: `monctl list`

Apply screen config (hz & color_depth are optional): `monctl "id:<screenId> res:<width>x<height> hz:<num> color_depth:<num> scaling:<on/off> origin:(<x>,<y>) degree:<0/90/180/270>"`

Apply screen config using mode: `monctl "id:<screenId> mode:<modeNum> origin:(<x>,<y>) degree:<0/90/180/270>"`

Apply screen config with mirrored screens: `monctl "id:<mainScreenId>+<1stMirrorScreenId>+<2ndMirrorScreenId> res:<width>x<height> scaling:<on/off> origin:(<x>,<y>) degree:<0/90/180/270>"`

Silence errors per-screen using quiet: `monctl "id:<screenId> mode:<modeNum> origin:(<x>,<y>) degree:0 quiet:true"`

Disable a screen: `monctl "id:<screenId> enabled:false"`

#### Instructions:
1. Manually set rotations 1st*, resolutions 2nd, and arrangement 3rd. For extra resolutions and rotations read 'Notes' below.
    - Open System Preferences -> Displays
    - Choose desired screen rotations (use monctl for rotating internal MacBook screen).
    - Choose desired resolutions (use monctl for extra resolutions).
    - Drag the white bar to your desired primary screen.
    - Arrange screens as desired and/or enable mirroring. To enable partial mirroring hold the alt/option key and drag a display on top of another.
2. Use `monctl list` to print your current layout's args, so you can create profiles for scripting/hotkeys with [Automator](https://github.com/jakehilborn/displayplacer/issues/13), BetterTouchTool, etc.

#### ScreenIds Switching:
Unfortunately, macOS sometimes changes the persistent screenIds when there are race conditions from external screens waking up in non-determinisic order. If none of the screenId options below work for your setup, please search around in displayplacer's GitHub Issues for conversation regarding this (this is inherited, upstream behavior, so the existing discussions still apply). Many people have written shell scripts to work around this issue. Recommended discussions are [one](https://github.com/jakehilborn/displayplacer/issues/80), [two](https://github.com/jakehilborn/displayplacer/issues/30), [three](https://github.com/jakehilborn/displayplacer/issues/89), [four](https://github.com/jakehilborn/displayplacer/issues/77), [five](https://github.com/jakehilborn/displayplacer/issues/100), [six](https://github.com/jakehilborn/displayplacer/pull/96).

You can mix and match screenId types across your setup.
- Persistent screenIds usually stay the same. They are recommended for most use cases.
- Contextual screenIds change when switching GPUs or when cables switch ports. If you notice persistent screenIds switching around, try using the contextual screenIds.
- Serial screenIds are tied to your display hardware. If the serial screenIds are unique for all of your monitors, use these.

#### Notes:
- *`monctl list` and system prefs only show resolutions for the screen's current rotation.
- Use an extra resolution shown in `monctl list` by executing `monctl "id:<screenId> mode:<modeNum>"`. Some of the resolutions listed do not work. If you select one, monctl will default to another working resolution.
- Rotate your internal MacBook screen by executing `monctl "id:<screenId> degree:<0/90/180/270>"`
- If you disable a screen, you may need to unplug/replug it to bring it back. However, on some setups, you can re-enable it with `monctl "id:<screenId> enabled:true"`
- The screen set to origin (0,0) will be set as the primary screen (white bar in system prefs).
- The first screenId in a mirroring set will be the 'Optimize for' screen in the system prefs. You can only choose resolutions for the 'Optimize for' screen. If there is a mirroring resolution you need but cannot find, try making a different screenId the first of the set.
- hz and color_depth are optional. If left out, the highest hz and then the highest color_depth will be auto applied.
- screenId is optional if there is only one screen. Rule of thumb is that monctl is expecting the entire profile config per screen though, so this may be buggy.

#### Backward Compatability:
`monctl list` output changed slightly in v1.4.0 (inherited from displayplacer). If this broke your scripts, use `monctl list --v1.3.0`.

#### Feedback:
Please create a GitHub Issue at [khaister/monctl](https://github.com/khaister/monctl) for any feedback, feature requests, or bugs specific to this fork. Happy to accept pull requests too!
