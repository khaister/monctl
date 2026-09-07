#!/usr/bin/env python3
"""Manual, hardware-dependent regression suite for monctl.

Run this BY HAND against your own real monitor setup. It is NOT part of CI - see
Tests/Integration/test_cli.py for the suite that runs there. This discovers whatever screens are
actually connected via `monctl list --json` and adapts its scenarios to however many are
present, instead of assuming a specific topology.

This WILL change your actual screen configuration while it runs (it restores your original
arrangement afterward via a `profile save`/`profile apply` round trip). Save your work first.
"""
import json
import re
import subprocess
import sys
import tempfile

BINARY = '../../.build/debug/monctl'
FAKE_UUID = '00000000-0000-0000-0000-000000000000'
RESTORE_PROFILE = 'tests-manual-restore-point'

failures = []


def monctl(args, extra_env=None):
    env = {'NO_COLOR': '1'}
    if extra_env:
        env.update(extra_env)
    p = subprocess.run(BINARY + ' ' + args, shell=True, capture_output=True, text=True, env={**__import__('os').environ, **env})
    return (p.stdout + p.stderr).strip(), p.returncode


def discover_screens():
    output, code = monctl('list --json')
    if code != 0:
        print('Could not run `monctl list --json` - aborting')
        sys.exit(1)
    return json.loads(output)


def test(step, args, expected_code=0, expected_error=None, extra_env=None):
    print(f'Executing {step}: monctl {args}')
    output, code = monctl(args, extra_env=extra_env)

    try:
        if expected_error:
            assert expected_error in output, f'expected {expected_error!r} in output'
        if expected_code is not None:
            assert code == expected_code, f'expected exit {expected_code}, got {code}'
    except AssertionError as e:
        failures.append(step)
        print(f'  FAILED: {e}')
        print(f'  output={output}')
        return
    print('  ok')


def test_reapply_current_profile_is_idempotent():
    # The one test that's fully topology-agnostic: whatever the current layout is, saving and
    # re-applying it should report "no change" for every screen.
    test('save_restore_point', f'profile save {RESTORE_PROFILE}')
    output, code = monctl(f'profile apply {RESTORE_PROFILE} --dry-run')
    ok = code == 0 and 'no change' in output and 'rotate' not in output and 'resolution' not in output
    print(f'{"PASS" if ok else "FAIL"}: reapplying the current layout reports no changes')
    if not ok:
        failures.append('reapply_current_profile_is_idempotent')
        print(f'  output={output}')


def test_missing_screen_reports_error(screens):
    test(
        'set_missing_screen_reports_error',
        f'set --screen {FAKE_UUID} --rotate 90',
        expected_code=1,
        expected_error=f'no screen matches id "{FAKE_UUID}"',
    )


def test_quiet_suppresses_missing_screen(screens):
    test(
        'set_quiet_suppresses_missing_screen',
        f'set --screen {FAKE_UUID} --rotate 90 --quiet',
        expected_code=0,
    )


def test_disable_enable_secondary_screen(screens):
    if len(screens) < 2:
        print('SKIP: disable/enable secondary screen test (needs 2+ screens, found %d)' % len(screens))
        return
    secondary = screens[1]['persistentID']
    test('disable_secondary_screen', f'set --screen {secondary} --enabled false')
    test('reenable_secondary_screen', f'set --screen {secondary} --enabled true')


def test_relative_placement(screens):
    if len(screens) < 2:
        print('SKIP: relative placement test (needs 2+ screens, found %d)' % len(screens))
        return
    primary, secondary = screens[0]['persistentID'], screens[1]['persistentID']
    test('place_secondary_right_of_primary', f'set --screen {secondary} --right-of {primary}')
    test('place_secondary_below_primary', f'set --screen {secondary} --below {primary}')


def test_mirroring(screens):
    if len(screens) < 2:
        print('SKIP: mirroring test (needs 2+ screens, found %d)' % len(screens))
        return
    primary, secondary = screens[0]['persistentID'], screens[1]['persistentID']
    test('enable_mirroring', f'set --screen {primary} --mirror {secondary}')
    test('disable_mirroring', f'set --screen {primary} --mirror ""')


def test_profile_apply_no_confirm_env(screens):
    test(
        'profile_apply_skips_prompt_with_no_confirm_env',
        f'profile apply {RESTORE_PROFILE}',
        expected_code=0,
        extra_env={'MONCTL_PROFILE_APPLY_NO_CONFIRM': '1'},
    )


def main():
    print('This suite changes your ACTUAL screen configuration. Save your work first.')
    print('')

    screens = discover_screens()
    print(f'Discovered {len(screens)} screen(s): {[s["persistentID"] for s in screens]}')
    print('')

    test_reapply_current_profile_is_idempotent()
    test_missing_screen_reports_error(screens)
    test_quiet_suppresses_missing_screen(screens)
    test_disable_enable_secondary_screen(screens)
    test_relative_placement(screens)
    test_mirroring(screens)
    test_profile_apply_no_confirm_env(screens)

    print('')
    print('Restoring original arrangement...')
    test('restore_original_arrangement', f'profile apply {RESTORE_PROFILE}',
         extra_env={'MONCTL_PROFILE_APPLY_NO_CONFIRM': '1'})
    monctl(f'profile rm {RESTORE_PROFILE}')

    if failures:
        print(f'\n{len(failures)} test(s) failed:')
        for f in failures:
            print(f'  - {f}')
        sys.exit(1)

    print('\nAll tests passed')


if __name__ == '__main__':
    main()
