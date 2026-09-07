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

Each screen's fields are alphabetized, except `modes` — by far the bulkiest field — which is
always last, after every scalar field, so it doesn't visually break up the rest when skimming
raw output.

`list --long`'s per-screen summary block (everything above `Modes:`) is rendered as
dot-leader-aligned lines, e.g.:

```
Screen 37D8832A-2D66-02CA-B9F7-8F30A301B230 (main)
  Persistent id ... 37D8832A-2D66-02CA-B9F7-8F30A301B230
  Contextual id ...................................... 1
  Serial id ................................ s4251086178
  Type ........................................ built-in
  Resolution ................................. 2056x1329
  Hz ............................................... 120
  Color Depth ........................................ 8
  Scaling ........................................... on
  Origin ......................................... (0,0)
  Rotation ........................................... 0
  Enabled ......................................... true
  Modes:
    ...
```

Every value's right edge lands in the same column, even `Persistent id`'s UUID — the rest of the
dot runs just stretch out to match it.

Which fields appear, their order, their labels, and how the result is paged are all overridable
in the config file — see [Configuration](#configuration) below.

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

## Configuration

monctl reads `~/.config/monctl/config.json` (XDG-style — `$XDG_CONFIG_HOME/monctl/config.json`
if that's set, alongside `profiles/`). Every key is optional; a missing file, or a key left out,
keeps that setting's default. If the file exists but fails to parse, monctl warns on stderr and
falls back to defaults rather than breaking the command.

Every setting below is also available as an environment variable.

> [!IMPORTANT]
> **If both are set, the environment variable always wins** — the config file value is only
> used when its environment variable is unset. This makes the env var a one-off override for a
> single shell or invocation, without having to edit `config.json`.

```json
{
  "listLongFields": [
    { "key": "type" },
    { "key": "resolution" },
    { "key": "hz" },
    { "key": "depth", "label": "Depth" },
    { "key": "scaling" },
    { "key": "enabled" }
  ],
  "pager": "less -R",
  "disablePager": false,
  "noColor": false,
  "editor": "vim",
  "profileApplyNoConfirm": false
}
```

| Config key | Env var | Default | Effect |
| --- | --- | --- | --- |
| `listLongFields` | `MONCTL_LIST_LONG_FIELDS` | every field, in the order below, with default labels | Which fields `list --long`'s per-screen summary block shows, their order, and their labels. In the config file, fields left out of the array are hidden entirely, and `label` is optional per entry (falls back to the default if omitted). The env var is a comma-separated list of `key` or `key:label` tokens instead, e.g. `type,resolution,hz,depth:Depth,scaling,enabled`. Valid `key`s: `persistentId`, `contextualId`, `serialId`, `type`, `resolution`, `hz`, `depth`, `scaling`, `origin`, `rotation`, `enabled`. |
| `pager` | `PAGER` | `less` | The pager `list --long` pipes through on a TTY. `PAGER` is the standard Unix variable, so most shells already have it set to a personal preference. |
| `disablePager` | `MONCTL_DISABLE_PAGER` | `false` | When `1`/`true`, `list --long` always prints plain output, even on a TTY — for people who never want a pager, without redirecting/piping every invocation. |
| `noColor` | `NO_COLOR` | `false` | Disables colored output everywhere monctl uses it (`list`, `set`, `profile apply`'s diff and confirmation prompt). `NO_COLOR` disables color on *any* value being set (not just `1`) per [no-color.org](https://no-color.org)'s convention. The `--no-color` flag (on `list`/`set`/`profile apply`/`profile show`) always wins over both, for a true one-off. |
| `editor` | `EDITOR` | `vi` | The editor `monctl profile edit <name>` opens the profile's JSON file in. |
| `profileApplyNoConfirm` | `MONCTL_PROFILE_APPLY_NO_CONFIRM` | `false` | When `1`/`true`, skips `profile apply`'s confirmation prompt and applies immediately — what a hotkey tool (Automator, BetterTouchTool) invoking `monctl profile apply <name>` should do, since it can't answer an interactive prompt. `--dry-run` previews the diff without prompting or applying, regardless of this setting. |
| *(none)* | `XDG_CONFIG_HOME` | `~/.config` | Base directory for both `config.json` and `profiles/*.json`. Env-var-only: it's what locates `config.json` in the first place, so it can't also be a key inside that file. |

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
> work around this. Recommended discussions: <https://github.com/jakehilborn/displayplacer/issues/80>,
> <https://github.com/jakehilborn/displayplacer/issues/30>, <https://github.com/jakehilborn/displayplacer/issues/89>,
> <https://github.com/jakehilborn/displayplacer/issues/77>, <https://github.com/jakehilborn/displayplacer/issues/100>,
> <https://github.com/jakehilborn/displayplacer/pull/96>.

See [Concepts](concepts.md#screen-identifiers) for what each screenId type is and when to use it.
