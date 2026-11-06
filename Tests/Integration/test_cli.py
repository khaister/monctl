#!/usr/bin/env python3
"""Hardware-independent, CI-safe black-box tests for the monctl CLI.

Every case here either never touches CoreGraphics (--help/--version/profile bookkeeping) or is
built on a deliberately nonexistent screen id, so it fails cleanly before touching real display
state - these behave identically on any machine, including a CI runner with just a virtual
display.

This does NOT verify that a valid config is actually applied correctly to a real screen (e.g.
that `set --resolution` picks the right mode) - only that the CLI handles the input without
crashing and reaches the expected code path. Actually applying configs is covered by
Tests/Integration/tests_manual.py, run by hand against real hardware.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

BINARY = os.environ.get('MONCTL_BINARY', os.path.join(os.path.dirname(__file__), '..', '..', '.build', 'debug', 'monctl'))
FAKE_UUID = '00000000-0000-0000-0000-000000000000'
FAKE_CONTEXTUAL_ID = '999999'
FAKE_SERIAL_ID = 's999999999'

failures = []


def run(*args, env=None):
    full_env = {**os.environ, 'NO_COLOR': '1'}
    if env:
        full_env.update(env)
    result = subprocess.run([BINARY, *args], capture_output=True, text=True, env=full_env)
    return result.stdout + result.stderr, result.returncode


def check(desc, cond):
    status = 'PASS' if cond else 'FAIL'
    print(f'{status}: {desc}')
    if not cond:
        failures.append(desc)


def discover_first_screen_id():
    output, code = run('list', '--json')
    if code != 0:
        return None
    try:
        screens = json.loads(output)
    except json.JSONDecodeError:
        return None
    return screens[0]['persistentID'] if screens else None


def test_help():
    output, code = run('--help')
    check('--help exits 0', code == 0)
    check('--help mentions USAGE', 'USAGE' in output)
    check('--help lists the list/set/profile/completion subcommands', all(
        f'\n  {name}' in output.replace('\n\n', '\n') or f'  {name} ' in output
        for name in ('list', 'set', 'profile', 'completion')
    ))


def test_no_args_prints_help():
    output, code = run()
    check('no args exits 0', code == 0)
    check('no args prints the same help as --help', 'USAGE' in output)


def test_version():
    output, code = run('--version')
    check('--version exits 0', code == 0)
    check('--version prints just a CalVer tag (vYYYY.MM.DD.N)', re.fullmatch(r'v\d{4}\.\d{2}\.\d{2}\.\d+', output.strip()) is not None)


def test_list_smoke():
    output, code = run('list')
    check('list exits 0', code == 0)
    check('list prints a header row', 'RESOLUTION' in output and 'ENABLED' in output)


def test_list_json_smoke():
    output, code = run('list', '--json')
    check('list --json exits 0', code == 0)
    try:
        screens = json.loads(output)
        check('list --json prints a JSON array', isinstance(screens, list))
        check('list --json entries have a persistentID', all('persistentID' in s for s in screens))
        # dict preserves insertion order (Python 3.7+), and json.loads doesn't reorder it, so
        # this reflects the actual key order in the JSON text.
        check('list --json puts modes last in every entry', all(list(s.keys())[-1] == 'modes' for s in screens))
    except json.JSONDecodeError:
        check('list --json prints valid JSON', False)


def test_list_json_key_order_is_deterministic():
    # This JSONEncoder's default (non-`.sortedKeys`) key order is NOT declaration/encode-call
    # order, it's effectively random per process - list --json works around this by hand for its
    # scalar/modes split (see ScreenInfoJSON.swift). Confirm two separate invocations agree.
    first, code1 = run('list', '--json')
    second, code2 = run('list', '--json')
    check('list --json exits 0 on repeated runs', code1 == 0 and code2 == 0)
    check('list --json key order is identical across separate invocations', first == second)


def test_list_long_shows_persistent_id():
    output, code = run('list', '--long')
    check('list --long exits 0', code == 0)
    if 'Screen ' not in output:
        print('SKIP: list --long persistent-id test (no screen discovered)')
        return
    check('list --long shows Persistent id', 'Persistent id ' in output)
    check(
        'Persistent id appears before Contextual id',
        0 <= output.find('Persistent id') < output.find('Contextual id'),
    )


def test_list_long_missing_screen():
    output, code = run('list', '--long', '--screen', FAKE_UUID)
    check('list --long --screen with a missing id reports the error', f'no screen matches id "{FAKE_UUID}"' in output)
    check('list --long --screen with a missing id exits 1', code == 1)


def test_set_missing_screen():
    output, code = run('set', '--screen', FAKE_UUID, '--rotate', '90')
    check('set on a missing persistent id reports the error', f'no screen matches id "{FAKE_UUID}"' in output)
    check('set on a missing persistent id exits 1', code == 1)


def test_set_missing_screen_contextual():
    output, code = run('set', '--screen', FAKE_CONTEXTUAL_ID, '--rotate', '90')
    check('set on a missing contextual id reports the error', f'no screen matches id "{FAKE_CONTEXTUAL_ID}"' in output)
    check('set on a missing contextual id exits 1', code == 1)


def test_set_missing_screen_serial():
    output, code = run('set', '--screen', FAKE_SERIAL_ID, '--rotate', '90')
    check('set on a missing serial id reports the conversion error', f'could not convert serial id "{FAKE_SERIAL_ID}"' in output)
    check('set on a missing serial id exits 1', code == 1)


def test_set_quiet_suppresses_missing_screen_error():
    output, code = run('set', '--screen', FAKE_UUID, '--rotate', '90', '--quiet')
    check('set --quiet suppresses the missing-screen message', 'no screen matches' not in output)
    check('set --quiet still exits 0', code == 0)


def test_set_rejects_bad_scaling():
    output, code = run('set', '--screen', FAKE_UUID, '--scaling', 'sideways')
    check('set --scaling rejects a non on/off value', '--scaling must be' in output)
    check('set --scaling with a bad value exits 64 (usage error)', code == 64)


def test_set_rejects_bad_rotation():
    output, code = run('set', '--screen', FAKE_UUID, '--rotate', '45')
    check('set --rotate rejects a value outside 0/90/180/270', '--rotate must be' in output)
    check('set --rotate with a bad value exits 64 (usage error)', code == 64)


def test_set_rejects_multiple_positioning_flags():
    output, code = run('set', '--screen', FAKE_UUID, '--origin', '0,0', '--right-of', FAKE_UUID)
    check('set rejects --origin combined with --right-of', 'only one of' in output)
    check('set with conflicting positioning flags exits 64 (usage error)', code == 64)


def test_set_right_of_missing_reference():
    real_id = discover_first_screen_id()
    if not real_id:
        print('SKIP: set --right-of missing-reference test (no screen discovered via `list --json`)')
        return
    output, code = run('set', '--screen', real_id, '--right-of', FAKE_UUID, '--dry-run')
    check('set --right-of a missing reference screen reports the error', f'no screen matches id "{FAKE_UUID}"' in output)
    check('set --right-of a missing reference screen exits 1', code == 1)


def test_set_dry_run_on_a_real_screen_is_a_no_op():
    real_id = discover_first_screen_id()
    if not real_id:
        print('SKIP: set --dry-run test (no screen discovered via `list --json`)')
        return
    output, code = run('set', '--screen', real_id, '--rotate', '0', '--dry-run')
    check('set --dry-run on an unchanged rotation reports no changes', 'No changes.' in output)
    check('set --dry-run exits 0', code == 0)


def test_set_missing_resolution_on_a_real_screen():
    real_id = discover_first_screen_id()
    if not real_id:
        print('SKIP: missing-resolution test (no screen discovered via `list --json`)')
        return
    output, code = run('set', '--screen', real_id, '--resolution', '99999x99999', '--dry-run')
    check('impossible resolution on a real screen reports the error', 'no mode on screen' in output and '99999x99999' in output)
    check('impossible resolution on a real screen exits 1', code == 1)


def test_list_long_config_override():
    with tempfile.TemporaryDirectory() as config_home:
        config_dir = os.path.join(config_home, 'monctl')
        os.makedirs(config_dir)
        config_path = os.path.join(config_dir, 'config.json')
        env = {'XDG_CONFIG_HOME': config_home}

        with open(config_path, 'w') as f:
            json.dump({'listLongFields': [
                {'key': 'type'},
                {'key': 'depth', 'label': 'Depth'},
            ]}, f)
        output, code = run('list', '--long', env=env)
        check('list --long config override exits 0', code == 0)
        check('list --long config override hides fields left out of listLongFields', 'Serial id' not in output)
        check('list --long config override renames a label', 'Depth ' in output and 'Color Depth' not in output)

        with open(config_path, 'w') as f:
            f.write('{ not json')
        output, code = run('list', '--long', env=env)
        check('list --long with a malformed config warns instead of failing', 'could not parse' in output)
        check('list --long with a malformed config still exits 0 (falls back to defaults)', code == 0)
        check('list --long falls back to default fields on a bad config', 'Color Depth' in output)

        # pager/disablePager only change behavior when stdout is a TTY, which subprocess.run()
        # never is - so this only proves the config keys parse cleanly, not that paging is
        # actually skipped/redirected. That needs a real pty to verify (done by hand).
        with open(config_path, 'w') as f:
            json.dump({'pager': 'cat', 'disablePager': True}, f)
        output, code = run('list', '--long', env=env)
        check('list --long parses pager/disablePager config keys without error', code == 0)
        check('list --long output is unaffected by pager config on a non-TTY stdout', 'Color Depth' in output)


def test_env_overrides_config_file():
    """Every config.json key has an environment variable counterpart, and when both are set the
    environment variable wins (see docs/usage.md's Configuration section). listLongFields is the
    setting whose precedence is observable here without touching real display state or a TTY.
    profileApplyNoConfirm's precedence needs a real (non-dry-run) `profile apply` to observe -
    that's covered in tests_manual.py instead, matching this file's screen-state-safe scope (see
    module docstring). pager/disablePager/noColor/editor only change TTY-dependent behavior, so
    those are covered by test_list_long_config_override's "parses without error" check plus
    manual pty verification.
    """
    with tempfile.TemporaryDirectory() as config_home:
        config_dir = os.path.join(config_home, 'monctl')
        os.makedirs(config_dir)
        config_path = os.path.join(config_dir, 'config.json')

        with open(config_path, 'w') as f:
            json.dump({'listLongFields': [{'key': 'type'}]}, f)
        output, code = run('list', '--long', env={
            'XDG_CONFIG_HOME': config_home,
            'MONCTL_LIST_LONG_FIELDS': 'hz',
        })
        check('$MONCTL_LIST_LONG_FIELDS overrides listLongFields when both are set', code == 0)
        check('  -> the env var\'s field is used', 'Hz ' in output)
        check('  -> the config file\'s field is not', 'Type ' not in output)


def test_profile_lifecycle():
    """Profiles are just files, so this is safe on CI: no real screen config is touched by
    save (a read-only snapshot) or list/show/rm (pure file operations) - only `profile apply`
    (not exercised here) would."""
    with tempfile.TemporaryDirectory() as config_home:
        env = {'XDG_CONFIG_HOME': config_home}
        name = 'ci-test-profile'

        output, code = run('profile', 'save', name, env=env)
        check('profile save exits 0', code == 0)
        check('profile save reports the saved path', f'Saved profile "{name}"' in output)

        output, code = run('profile', 'list', env=env)
        check('profile list shows the saved profile', name in output)

        output, code = run('profile', 'show', name, '--json', env=env)
        check('profile show --json exits 0', code == 0)
        try:
            configs = json.loads(output)
            check('profile show --json prints a JSON array', isinstance(configs, list))
        except json.JSONDecodeError:
            check('profile show --json prints valid JSON', False)

        output, code = run('profile', 'apply', name, '--dry-run', env=env)
        check('profile apply --dry-run exits 0', code == 0)
        check('profile apply --dry-run prints a would-apply header', f'Would apply profile "{name}"' in output)

        output, code = run('profile', 'rm', name, env=env)
        check('profile rm exits 0', code == 0)
        check('profile rm confirms removal', f'Removed profile "{name}"' in output)

        output, code = run('profile', 'show', name, env=env)
        check('profile show after rm reports the error', f'no profile named "{name}"' in output)
        check('profile show after rm exits 1', code == 1)


def test_profile_apply_missing_profile():
    output, code = run('profile', 'apply', 'no-such-profile-xyz')
    check('profile apply on a missing profile reports the error', 'no profile named "no-such-profile-xyz"' in output)
    check('profile apply on a missing profile exits 1', code == 1)


def test_completion():
    output, code = run('completion', 'zsh')
    check('completion zsh exits 0', code == 0)
    check('completion zsh prints a zsh completion script', '#compdef monctl' in output)

    output, code = run('completion', 'nonexistent-shell')
    check('completion with an unknown shell reports the error', 'unsupported shell' in output)
    check('completion with an unknown shell exits 1', code == 1)


def main():
    if not os.path.exists(BINARY):
        print(f'monctl binary not found at {BINARY} - build it first (swift build)')
        sys.exit(1)
    if shutil.which('less') is None:
        print('note: `less` not found on PATH - list --long paging fallback is untested here')

    test_help()
    test_no_args_prints_help()
    test_version()
    test_list_smoke()
    test_list_json_smoke()
    test_list_json_key_order_is_deterministic()
    test_list_long_shows_persistent_id()
    test_list_long_missing_screen()
    test_set_missing_screen()
    test_set_missing_screen_contextual()
    test_set_missing_screen_serial()
    test_set_quiet_suppresses_missing_screen_error()
    test_set_rejects_bad_scaling()
    test_set_rejects_bad_rotation()
    test_set_rejects_multiple_positioning_flags()
    test_set_right_of_missing_reference()
    test_set_dry_run_on_a_real_screen_is_a_no_op()
    test_set_missing_resolution_on_a_real_screen()
    test_list_long_config_override()
    test_env_overrides_config_file()
    test_profile_lifecycle()
    test_profile_apply_missing_profile()
    test_completion()

    if failures:
        print(f'\n{len(failures)} check(s) failed:')
        for f in failures:
            print(f'  - {f}')
        sys.exit(1)

    print('\nAll checks passed')


if __name__ == '__main__':
    main()
