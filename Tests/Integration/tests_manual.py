#!/usr/bin/env python3
"""Manual, hardware-dependent regression suite for monctl.

Run this BY HAND against your own real monitor setup. It is NOT part of CI -
see Tests/Unit/ for the suite that runs there. This discovers whatever
screens are actually connected via `monctl list` and adapts its
scenarios to however many are present, instead of assuming a specific
topology - previous versions of this file hardcoded UUIDs from the original
developer's own 4-monitor Mac and could only ever run there.

This WILL change your actual screen configuration while it runs (it restores
your original arrangement afterward, via the same `list`-reconstructed
command the README recommends for scripting profiles). Save your work first.

Known gotcha this suite works around: a screen entry that's enabled (the
default, or explicit `enabled:true`) but omits `res:`/`origin:`/`degree:`
reads uninitialized memory for those fields (only `enabled:false` short-
circuits before reaching them) - e.g. `id:<real> enabled:true` alone reliably
fails with a garbage `could not find res:0x0` error. This is a pre-existing
bug, out of scope to fix here, but it means any screen this suite wants left
"as-is" must be given its real current res/origin/degree/etc, never a bare
enabled:true - see `screen_properties()` below.
"""
import re
import subprocess
import sys

BINARY = '../../.build/debug/monctl'
FAKE_UUID = '00000000-0000-0000-0000-000000000000'

failures = []


def monctl(args):
    p = subprocess.Popen(BINARY + ' ' + args, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = p.communicate()[0].decode('utf-8').strip()
    code = p.wait()
    return output, code


def discover_screens():
    output, code = monctl('list')
    if code != 0:
        print('Could not run `monctl list` - aborting')
        sys.exit(1)
    return re.findall(r'Persistent screen id: (\S+)', output)


def current_profile_command():
    """The reconstructed `monctl "..."` command for whatever is live right now."""
    output, code = monctl('list')
    last_line = output.splitlines()[-1]
    assert last_line.startswith('monctl ')
    return last_line[len('monctl '):]


def screen_properties(conf, uuid):
    """The key:value tokens (everything but `id:...`) for one screen's snippet
    within a multi-screen conf string, e.g. ['res:2056x1329', 'hz:120', ...].
    Used to build new configs that leave a screen's real current state intact
    instead of a bare `enabled:true`, which hits the uninitialized-memory bug
    described in the module docstring."""
    for segment in re.findall(r'"[^"]*"', conf):
        tokens = segment[1:-1].split()
        primary_id = tokens[0][len('id:'):].split('+')[0]
        if primary_id == uuid:
            return tokens[1:]
    raise ValueError(f'no snippet found for screen {uuid} in: {conf}')


def test(step, conf, expected_conf=None, expected_code=0, expected_error=None):
    print(f'Executing {step}')
    output, code = monctl(conf)

    try:
        if expected_error:
            assert expected_error in output
        if expected_code is not None:
            assert code == expected_code
        if expected_conf:
            list_output, list_code = monctl('list')
            target = conf if expected_conf == 'match_input' else expected_conf
            assert list_output.splitlines()[-1] == 'monctl ' + target
            assert list_code == 0
    except AssertionError as e:
        failures.append(step)
        print(f'  FAILED. code={code}')
        print(f'  output={output}')
        return
    print('  ok')


def test_reapply_current_profile_is_idempotent(original_conf):
    # The one test that's fully topology-agnostic: whatever `list` says is
    # live right now, reapplying it should round-trip back to itself exactly.
    # This replaces the old hardcoded per-machine `reset_conf` and is also
    # used to restore your original arrangement at the end.
    test('reapply_current_profile_matches_input', original_conf, 'match_input', 0, None)


def test_single_screen_no_id_required(screens):
    if len(screens) != 1:
        print('SKIP: single-screen-no-id test (needs exactly 1 active screen, found %d)' % len(screens))
        return
    # Can't assert an exact expected_conf or exit code here since success
    # depends on whether res:1920x1080 happens to be a mode your one screen
    # actually supports - just confirm it runs without crashing.
    test('set_conf_without_passing_in_id', 'res:1920x1080', expected_code=None)


def test_missing_screen_partial_application(screens, original_conf):
    real_uuid = screens[0]
    real_props = ' '.join(screen_properties(original_conf, real_uuid))
    conf = f'"id:{FAKE_UUID} enabled:false" "id:{real_uuid} {real_props}"'
    test('missing_screen_partial_error_others_still_applied', conf,
         expected_code=1, expected_error=f'Unable to find screen {FAKE_UUID}')


def test_quiet_mode_suppresses_missing_screen(screens, original_conf):
    real_uuid = screens[0]
    real_props = ' '.join(screen_properties(original_conf, real_uuid))
    conf = f'"id:{FAKE_UUID} enabled:false quiet:true" "id:{real_uuid} {real_props}"'
    test('missing_screen_quiet_mode_suppresses_error', conf, expected_code=0)


def test_disable_enable_secondary_screen(screens, original_conf):
    if len(screens) < 2:
        print('SKIP: disable/enable secondary screen test (needs 2+ screens, found %d)' % len(screens))
        return
    secondary = screens[1]
    secondary_props = ' '.join(screen_properties(original_conf, secondary))
    test('disable_secondary_screen', f'"id:{secondary} enabled:false"')
    test('reenable_secondary_screen', f'"id:{secondary} {secondary_props}"')


def test_mirroring(screens, original_conf):
    if len(screens) < 2:
        print('SKIP: mirroring test (needs 2+ screens, found %d)' % len(screens))
        return
    primary, secondary = screens[0], screens[1]
    primary_props = ' '.join(screen_properties(original_conf, primary))
    secondary_props = ' '.join(screen_properties(original_conf, secondary))
    test('enable_mirroring', f'"id:{primary}+{secondary} {primary_props}"')
    test('disable_mirroring', f'"id:{primary} {primary_props}" "id:{secondary} {secondary_props}"')


def main():
    print('This suite changes your ACTUAL screen configuration. Save your work first.')
    print('')

    screens = discover_screens()
    print(f'Discovered {len(screens)} screen(s): {screens}')
    print('')

    original_conf = current_profile_command()

    test_reapply_current_profile_is_idempotent(original_conf)
    test_single_screen_no_id_required(screens)
    test_missing_screen_partial_application(screens, original_conf)
    test_quiet_mode_suppresses_missing_screen(screens, original_conf)
    test_disable_enable_secondary_screen(screens, original_conf)
    test_mirroring(screens, original_conf)

    print('')
    print('Restoring original arrangement...')
    test('restore_original_arrangement', original_conf, 'match_input', None, None)

    if failures:
        print(f'\n{len(failures)} test(s) failed:')
        for f in failures:
            print(f'  - {f}')
        sys.exit(1)

    print('\nAll tests passed')


if __name__ == '__main__':
    main()
