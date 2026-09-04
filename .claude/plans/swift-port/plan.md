# Phase 1: Port displayplacer to Swift (UX unchanged)

## Phase 0: Pre-port validation (do this first)

Before writing any Swift, establish a baseline:

1. **Do the existing tests still pass today?** Build the current C/ObjC binary
   from `src/Makefile` and run `test/tests.py` against it as-is. The suite
   hardcodes UUIDs and multi-screen topologies from the original developer's
   machine, so on this machine most `id:`-targeted assertions are expected to
   fail on "screen not found" rather than reveal real regressions — the
   interesting signal is whether the *binary itself* still builds and runs
   correctly against the current macOS/SDK, and whether any failures look like
   genuine bugs vs. environment mismatch.
2. **Where are the test suite's coverage gaps?** Diff `test/tests.py`'s actual
   test cases against the full behavior surface documented in `README.md` and
   implemented in `src/DisplayPlacer.c`/`src/Legacy/v130.c` (e.g. `--help`,
   `--version`, error-message wording, `mode:N` targeting, disabled-screen
   re-enable, edge cases in the `key:value` parser) to find what's untested.

**The outcome of these two determines the next step** — e.g. whether we adapt
the suite to be portable/runnable here first, write missing coverage before
porting, or proceed straight to the Swift port using manual verification only.

## Context

`displayplacer` (built as `monctl`) is a ~1,350-line macOS CLI for multi-monitor
configuration, currently written in C/Objective-C. The long-term goal is to
modernize its UX (subcommands, friendly screen names, profiles), but we're
doing that in phases. **Phase 1 is a pure language port: rewrite the
orchestration/parsing/output logic in Swift, keep the CLI's inputs and outputs
byte-for-byte identical, and verify it still works before touching UX at all.**

The codebase leans on undocumented private APIs in two isolated places:
- `CGSGetCurrentDisplayMode` / `CGSConfigureDisplayMode` / etc. (private
  CoreGraphics Services functions) and the reverse-engineered `modes_D4` byte
  union, both declared in `src/Header.h`.
- The private `MonitorPanel.framework` (`MPDisplay`), used only in
  `src/MonitorPanel.m` to implement `setRotation()`.

Per earlier discussion: we don't need to "port" this private-API surface —
Swift can call it as-is through C/Objective-C interop. So this plan keeps that
surface in C/ObjC, unchanged in behavior, and ports everything else
(argument parsing, `ScreenConfig` orchestration, screen enumeration, output
formatting, help/version text) to Swift.

## Architecture

Replace the hand-rolled `Makefile` with a Swift Package Manager package
containing two targets:

- **`CDisplayCore`** (C/Objective-C target) — the private-API boundary,
  unchanged in behavior, just reorganized:
  - `MonitorPanel.m` moves in as-is; still exports `setRotation(CGDirectDisplayID, char*, int)`.
  - New `DisplayModes.c` (extracted verbatim from `Header.h`'s private CGS
    declarations + `CopyAllDisplayModes`) adds a **thin safe wrapper** around
    `modes_D4` so Swift never has to do raw unaligned-union pointer math:
    ```c
    typedef struct {
        int mode, width, height, depth, freq;
        float density;
    } DisplayMode;
    int getDisplayModeCount(CGDirectDisplayID display);
    DisplayMode getDisplayMode(CGDirectDisplayID display, int index);
    int getCurrentDisplayModeIndex(CGDirectDisplayID display);
    bool configureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);
    bool configureDisplayEnabled(CGDisplayConfigRef config, CGDirectDisplayID display, bool enabled);
    ```
    This is the only new code in the private-API layer, and it doesn't change
    any CGS call or its behavior — it just gives Swift a plain struct instead
    of a raw byte union.
  - `include/CDisplayCore.h` umbrella header + the existing
    `MonitorPanel.framework/Headers/*.h` copied in as-is.

- **`displayplacer`** (Swift executable target) — everything else, 1:1 ported
  from `src/DisplayPlacer.c` and `src/Legacy/v130.c`:
  - `main.swift` — argv dispatch (`--help`, `--version`, `list`,
    `list --v1.3.0`, apply-config), mirrors current `main()` control flow
    including the "default to the only active screen if no id given" logic.
  - `ScreenConfig.swift` — Swift struct port of the C `ScreenConfig`.
  - `ArgumentParser.swift` — port of the `key:value`-DSL parser (currently
    `strtok_r`-based), including the legacy `res:WxHxHz` compat form and the
    `id:main+mirror1+mirror2` mirror syntax.
  - `ScreenID.swift` — `convertUUIDtoID` / `convertSerialToID` /
    `validateScreenOnline`, using public CoreGraphics/CFUUID APIs (no
    private-API dependency, safe to port).
  - `DisplayConfigurator.swift` — `setEnableds/setEnabled`,
    `unsetMirrors/unsetMirror`, `setRotations` (calls into `CDisplayCore.setRotation`),
    `setMirrors/setMirror`, `setResolutions/setResolution` (calls into the new
    `DisplayMode` wrapper), `setPositions/setPosition`.
  - `ScreenLister.swift` — `listScreens` + `printCurrentProfile`, **and** the
    `--v1.3.0` legacy-format variants (currently duplicated in `v130.c`) —
    ported as a formatting-mode flag on shared enumeration code rather than
    kept as parallel C, since neither depends on anything more private than
    the main path already does.
  - `HelpText.swift` — `printHelp` / `printVersion`, string-for-string port.

- `test/tests.py` stays as the reference contract for expected output/behavior
  (see Verification) but is not itself runnable here — it hardcodes UUIDs from
  the original developer's specific monitor setup.

## Key risk: linking private frameworks under SPM

The current `Makefile` links against frameworks outside the standard SDK:
`-F/System/Library/PrivateFrameworks -framework MonitorPanel -framework SkyLight
-framework OSD -framework CoreDisplay -framework DisplayServices`. SPM needs
`unsafeFlags` in `cSettings`/`linkerSettings` on the `CDisplayCore` target to
replicate this, which also means the package can't be consumed as a remote
SwiftPM dependency (irrelevant here — it's a leaf CLI product, not a library).

**First implementation step is a spike**: create the minimal `Package.swift` +
`CDisplayCore` target and confirm `swift build` successfully links against
`MonitorPanel`/`SkyLight`/`OSD`/`CoreDisplay` before porting any logic. If
`unsafeFlags` doesn't work cleanly, fall back to a `module.modulemap` +
explicit `-Xlinker` flags via `swiftSettings`/`unsafeFlags` on the executable
target instead.

## Verification

This session is running on macOS (Darwin), so read-only paths can be verified
directly:
1. Build both the old Makefile binary and the new SPM binary.
2. Diff `--help`, `--version`, and `list` output character-for-character
   between the two binaries on the actual machine's real displays.
3. Manually walk the `key:value` DSL parsing against every example in
   `test/tests.py` and the README (mirroring, `quiet:true`, `mode:N` vs
   `res:WxH`, legacy `res:WxHxHz`, single-screen-no-id-given) to confirm the
   Swift parser produces identical `ScreenConfig` values.

Config-*mutating* commands (rotate/position/mirror/resolution changes) alter
the user's live monitor arrangement — those should be run interactively with
the user watching, not unattended, and only after explicit go-ahead per run.

## Out of scope (deferred to a later phase)

No UX changes: no subcommands, no friendly screen names, no profiles, no
`--json`. The Swift CLI's argv contract must match the current C binary
exactly.
