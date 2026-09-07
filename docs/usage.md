# Usage

Show connected screens:

```sh
monctl list
```

Show full detail for one screen — alternate ids, exact depth, every mode it supports:

```sh
monctl list --long --screen <id>
```

Narrow the mode list to one resolution's hz/depth/scaling combos:

```sh
monctl list --long --screen <id> --resolution <width>x<height>
```

Machine-readable output (always full detail, regardless of `--long`):

```sh
monctl list --json
```

## Adjusting one screen

`monctl set` changes one screen at a time. Only pass the flags for what you want to change —
everything else is left alone.

```sh
monctl set --screen <id> --resolution <width>x<height>   # hz/depth auto-pick the best match
monctl set --screen <id> --mode <modeNum>                # exact mode from `list --long`
monctl set --screen <id> --rotate <0|90|180|270>
monctl set --screen <id> --enabled <true|false>
```

Preview a change without applying it:

```sh
monctl set --screen <id> --rotate 90 --dry-run
```

### Arrangement

Relative placement flags compute the origin from another screen's current bounds, so you don't
have to work out pixel offsets by hand:

```sh
monctl set --screen <id> --right-of <otherId>
monctl set --screen <id> --left-of <otherId>
monctl set --screen <id> --above <otherId>
monctl set --screen <id> --below <otherId>
```

`--origin x,y` sets a raw pixel origin directly, for placements the relative flags can't express
(partial overlap, vertically centering screens of different heights, staggered arrangements). See
[Concepts](concepts.md#origin) for what origin means.

### Mirroring

```sh
monctl set --screen <id> --mirror <otherId>[,<otherId>...]
```

## Profiles

A profile is a saved, named layout — the replacement for copy-pasting `monctl list` output into
Automator or BetterTouchTool.

```sh
monctl profile save <name>          # capture the current layout
monctl profile apply <name>         # re-apply it later (prompts with a diff first, see below)
monctl profile list                 # list saved profiles
monctl profile show <name>          # print one (or --json)
monctl profile rm <name>            # delete one
monctl profile edit <name>          # open the profile's JSON in $EDITOR
```

`profile apply` always prints a diff of what's about to change and asks for confirmation before
applying:

```
$ monctl profile apply docked
Apply profile "docked":
  Screen 1: no change
  Screen 2: rotate 0 -> 90, origin (1920,0) -> (0,0)
Apply this? [y/N]
```

Set `MONCTL_PROFILE_APPLY_NO_CONFIRM=1` to skip the prompt — this is what a hotkey tool
(Automator, BetterTouchTool) invoking `monctl profile apply <name>` should do, since it can't
answer an interactive prompt. `--dry-run` previews the same diff without prompting or applying,
on or off that env var.

Profiles are stored as human-editable JSON under `~/.config/monctl/profiles/<name>.json`, so they
work fine in a dotfiles repo.

## Shell completion

```sh
monctl completion zsh   # or bash, fish
```

See your shell's docs for where to put the generated script (e.g. a file sourced by your
`.zshrc`, or a directory on `$fpath`).

## Notes

- `monctl list` and System Preferences only show resolutions for the screen's *current*
  rotation.
- `hz` and `depth` are optional on `--resolution`. If omitted, the highest hz and then the
  highest color depth are applied automatically.
- If you disable a screen, you may need to unplug/replug it to bring it back. On some setups you
  can re-enable it instead: `monctl set --screen <id> --enabled true`.
- The first screen id passed to `--mirror`'s *primary* screen is the "Optimize for" screen in
  System Preferences — resolution choices apply to that screen; the mirroring ids on `--mirror`
  itself are the ones that will display it scaled to fit.

## ScreenIds switching

> [!WARNING]
> macOS sometimes changes persistent screenIds when there are race conditions from external
> screens waking up in non-deterministic order. If none of the screenId options work for your
> setup, search displayplacer's GitHub Issues for conversation on this — it's inherited, upstream
> behavior, so the existing discussions still apply. Many people have written shell scripts to
> work around this. Recommended discussions: https://github.com/jakehilborn/displayplacer/issues/80,
> https://github.com/jakehilborn/displayplacer/issues/30, https://github.com/jakehilborn/displayplacer/issues/89,
> https://github.com/jakehilborn/displayplacer/issues/77, https://github.com/jakehilborn/displayplacer/issues/100,
> https://github.com/jakehilborn/displayplacer/pull/96.

See [Concepts](concepts.md#screen-identifiers) for what each screenId type is and when to use it.
