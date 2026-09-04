# Step 1: Enhance test suite + CI (land on main first)

## Context

We validated the existing setup: the C/ObjC binary builds cleanly on this
machine, but `test/tests.py` hardcodes UUIDs and a 4-screen topology from the
original developer's own Mac, so it can't run anywhere else — it crashes on
the very first assertion here (1 screen, none of the hardcoded IDs match) and
has no per-test isolation (one failure aborts the whole run). It also misses
several documented behaviors entirely: `--help`, `--version`,
`list --v1.3.0`, `mode:N` targeting, legacy `res:WxHxHz`, standalone
enable/disable, degree:270, and parser edge cases.

Agreed sequencing across the whole effort:
1. **(this plan)** Enhance the test suite, get it passing, add CI, merge to `main`.
2. On a new branch: rename `displayplacer` → `monctl` everywhere, leaning on
   the now-working test suite to catch regressions.
3. (Later, separate plan) Port to Swift, UX unchanged.

This plan covers **only step 1**. No renaming, no Swift, no UX changes.

## Design: two tiers, split by hardware dependency

- **CI-safe (no real display needed)**: most of today's gaps are actually
  hardware-independent by construction — `--help`/`--version` never touch
  CoreGraphics at all, and the "missing screen" / "missing resolution" /
  `quiet:true` / parser-edge-case paths all fail cleanly on a **deliberately
  fake** UUID or resolution before touching real display state, so they
  behave identically on any machine, including a CI runner with just a
  virtual display. These can all be covered by **black-box subprocess tests**
  against the built binary — no source refactor required, same style as the
  existing `test/tests.py`.
- **Manual-only (needs a dev's real hardware)**: actually applying a valid
  resolution/rotation/position/mirror change and confirming it took effect.
  This stays in a generalized, hardware-discovering version of
  `test/tests.py`, run manually, never in CI.
- **One exception needing a real C refactor**: the "auto-pick highest hz,
  then highest depth when hz/depth are omitted" mode-selection algorithm
  (currently inlined in `setResolution()` in `src/DisplayPlacer.c`) can't be
  black-box tested without a real screen exposing multiple matching modes —
  and it's the exact kind of logic that caused the v1.2 regression the
  current suite guards against (`set_problematic_profile` test). Per
  decision: extract it into a standalone, hardware-independent function and
  add real C unit tests with a fabricated mode list.

## Concrete changes

- **`src/DisplayPlacer.c` / `src/Header.h`**: extract the mode-matching loop
  out of `setResolution()` into a new pure function, e.g.:
  ```c
  modes_D4* selectBestMode(modes_D4* modes, int modeCount, int width, int height, int hz, int depth, bool scaled);
  ```
  Behavior must be byte-identical to today's inlined loop —
  `setResolution()` calls this instead of containing the loop itself.
  `CopyAllDisplayModes` (the actual private-API call) is untouched.

- **`test/unit/`** (new, CI-safe, no private frameworks linked):
  - `test_mode_selection.c` — unit tests for `selectBestMode()`: exact match,
    hz omitted → highest hz, hz matched/depth omitted → highest depth, no
    match → NULL, and the v1.2 regression case reconstructed from
    `set_problematic_profile`'s test data in `test/tests.py`.
  - A small custom assert-and-report runner (no external test framework —
    matches this project's zero-dependency style). Builds as its own binary,
    independent of `MonitorPanel.m`/private frameworks, so it links and runs
    on any macOS box including a bare CI runner.
  - `test_cli_blackbox.py` (or extend `test/tests.py` — see below) — black-box
    subprocess tests covering `--help`, `--version`, `list` (smoke: exit 0,
    expected structural markers, no assertions on exact resolution/hz since
    CI hardware is unpredictable), missing-screen error, missing-resolution
    error (3 id-type variants), `quiet:true` suppression, `mode:N` vs
    `res:WxH`, legacy `res:WxHxHz`, and malformed-input handling — all built
    on deliberately nonexistent screen IDs/resolutions so they need no real
    matching hardware.

- **`src/Makefile`**: add a `test` (or `unit-test`) target that builds and
  runs `test/unit/test_mode_selection.c` standalone (no framework linking),
  separate from the `displayplacer` target.

- **`test/tests.py`**: generalize instead of hardcoding one developer's
  topology — call `displayplacer list` first to discover whatever screens are
  actually connected, build test profiles from that, and skip scenarios that
  need more screens than are present (e.g. skip mirroring on a 1-screen
  machine). Add a comment at the top marking it dev-run-only, not part of CI.
  Keep the existing test cases' intent; just make them hardware-adaptive.

- **`.github/workflows/test.yml`** (new):
  ```yaml
  on:
    pull_request:
    push:
      branches: [main]
  jobs:
    test:
      runs-on: macos-latest
      steps:
        - uses: actions/checkout@v4
        - run: make -C src              # smoke: full binary still builds/links
        - run: make -C src test         # unit tests (mode selection)
        - run: python3 test/test_cli_blackbox.py   # hardware-independent black-box suite
  ```
  Does **not** run `test/tests.py` (the hardware-dependent manual suite).

## Risks

- Whether GitHub's macOS runners actually have
  `/System/Library/PrivateFrameworks/{MonitorPanel,SkyLight,OSD,CoreDisplay,DisplayServices}.framework`
  at link time is unverified from here (private frameworks ship with the OS,
  not Xcode, so they should be present on any real macOS install — but this
  needs confirming by watching the first actual CI run, not assumed).
- Extracting `selectBestMode()` must not change `setResolution()`'s behavior —
  verify by diffing `list`/apply output on this machine before and after.

## Verification

1. `make -C src` — full binary still builds clean (as it does today).
2. `make -C src test` — new unit tests pass locally.
3. `python3 test/test_cli_blackbox.py` — black-box suite passes locally.
4. `python3 test/tests.py` — generalized manual suite runs on this machine's
   real (single) screen without crashing (most scenarios will skip since they
   need 2+ screens, but it shouldn't error out).
5. Push a branch, open a PR against `main`, confirm `test.yml` runs on PR open
   and goes green — this is also where risk #1 above gets resolved for real.
6. Merge PR to `main`, confirm `test.yml` also runs on the resulting push to
   `main`.

## Out of scope

No renaming to `monctl` (step 2, separate branch after this merges). No Swift
port. No UX changes. No refactor of `listScreens`/`printCurrentProfile`
formatting code beyond what's needed for `selectBestMode()` extraction.
