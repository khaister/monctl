#!/usr/bin/env python3
"""Hardware-independent, CI-safe black-box tests for the displayplacer CLI.

Every case here either never touches CoreGraphics (--help/--version) or is
built on a deliberately nonexistent screen id/resolution, so it fails cleanly
before touching real display state - these behave identically on any
machine, including a CI runner with just a virtual display.

This does NOT verify that a valid config is actually applied correctly to a
real screen (e.g. that a legacy `res:WxHxHz` string parses to the right
width/height/hz) - only that the CLI handles the input without crashing and
reaches the expected code path. Actually applying configs is covered by
tests/tests_manual.py, run by hand against real hardware.
"""
import os
import re
import subprocess
import sys

BINARY = os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'displayplacer')
FAKE_UUID = '00000000-0000-0000-0000-000000000000'
FAKE_CONTEXTUAL_ID = '999999'
FAKE_SERIAL_ID = 's999999999'

failures = []


def run(*args):
    result = subprocess.run([BINARY, *args], capture_output=True, text=True)
    return result.stdout + result.stderr, result.returncode


def check(desc, cond):
    status = 'PASS' if cond else 'FAIL'
    print(f'{status}: {desc}')
    if not cond:
        failures.append(desc)


def discover_first_screen_uuid():
    output, code = run('list')
    if code != 0:
        return None
    match = re.search(r'Persistent screen id: (\S+)', output)
    return match.group(1) if match else None


def test_help():
    output, code = run('--help')
    check('--help exits 0', code == 0)
    check('--help mentions Usage:', 'Usage:' in output)
    check('--help mentions Instructions:', 'Instructions:' in output)
    check('--help mentions Feedback:', 'Feedback:' in output)


def test_no_args_prints_help():
    output, code = run()
    check('no args exits 0', code == 0)
    check('no args prints the same help as --help', 'Usage:' in output and 'Feedback:' in output)


def test_version():
    output, code = run('--version')
    check('--version exits 0', code == 0)
    check('--version mentions displayplacer v', 'displayplacer v' in output)
    check('--version mentions the developer', 'Developer: Jake Hilborn' in output)


def test_list_smoke():
    output, code = run('list')
    check('list exits 0', code == 0)
    check('list mentions Persistent screen id', 'Persistent screen id:' in output)
    check('list mentions Serial screen id (v1.4.0+ format)', 'Serial screen id:' in output)
    check('list prints a reconstructed displayplacer command', 'displayplacer "id:' in output)


def test_list_legacy_format_smoke():
    output, code = run('list', '--v1.3.0')
    check('list --v1.3.0 exits 0', code == 0)
    check('list --v1.3.0 mentions Persistent screen id', 'Persistent screen id:' in output)
    check('list --v1.3.0 omits Serial screen id (pre-v1.4.0 format)', 'Serial screen id:' not in output)


def test_missing_screen_persistent_id():
    output, code = run(f'id:{FAKE_UUID} res:1920x1080')
    check('missing persistent screen id reports the error', f'Unable to find screen {FAKE_UUID}' in output)
    check('missing persistent screen id exits 1', code == 1)


def test_missing_screen_contextual_id():
    output, code = run(f'id:{FAKE_CONTEXTUAL_ID} res:1920x1080')
    check('missing contextual screen id reports the error', f'Unable to find screen {FAKE_CONTEXTUAL_ID}' in output)
    check('missing contextual screen id exits 1', code == 1)


def test_missing_screen_serial_id():
    output, code = run(f'id:{FAKE_SERIAL_ID} res:1920x1080')
    check('missing serial screen id reports the conversion error', f'Error converting serialId {FAKE_SERIAL_ID}' in output)
    check('missing serial screen id reports the not-found error', f'Unable to find screen {FAKE_SERIAL_ID}' in output)
    check('missing serial screen id exits 1', code == 1)


def test_quiet_suppresses_missing_screen_error():
    output, code = run(f'id:{FAKE_UUID} res:1920x1080 quiet:true')
    check('quiet:true suppresses the missing-screen message', 'Unable to find screen' not in output)
    check('quiet:true still exits 0', code == 0)


def test_malformed_key_is_rejected():
    output, code = run('zzz:invalid')
    check('unknown key reports a parsing error', 'Argument parsing error' in output)
    check('unknown key exits 1', code == 1)


def test_mode_targeting_syntax_is_parsed():
    # mode:N on a nonexistent screen still hits the same missing-screen path,
    # which is the only way to exercise the parser without touching a real
    # screen's actual mode table.
    output, code = run(f'id:{FAKE_UUID} mode:5')
    check('mode:N syntax parses and reaches the missing-screen path', f'Unable to find screen {FAKE_UUID}' in output)
    check('mode:N on missing screen exits 1', code == 1)


def test_legacy_res_format_is_parsed():
    # Legacy 3-part `res:WxHxHz` on a nonexistent screen - same caveat as above:
    # this only proves the parser doesn't crash on the legacy format, not that
    # it extracts the right width/height/hz (needs a real matching screen).
    output, code = run(f'id:{FAKE_UUID} res:1440x900x60')
    check('legacy res:WxHxHz parses and reaches the missing-screen path', f'Unable to find screen {FAKE_UUID}' in output)
    check('legacy res:WxHxHz on missing screen exits 1', code == 1)


def test_missing_resolution_on_a_real_screen():
    # The one case that needs a real screen id to even reach the resolution
    # lookup - but any screen works, and 99999x99999 doesn't exist on any
    # real or virtual display, so this is safe and portable across machines.
    screen_uuid = discover_first_screen_uuid()
    if not screen_uuid:
        print('SKIP: missing-resolution test (no screen discovered via `list`)')
        return

    output, code = run(f'id:{screen_uuid} res:99999x99999')
    check('impossible resolution on a real screen reports the error', f'Screen ID {screen_uuid}: could not find res:99999x99999' in output)
    check('impossible resolution on a real screen exits 1', code == 1)


def main():
    if not os.path.exists(BINARY):
        print(f'displayplacer binary not found at {BINARY} - build it first (make -C src)')
        sys.exit(1)

    test_help()
    test_no_args_prints_help()
    test_version()
    test_list_smoke()
    test_list_legacy_format_smoke()
    test_missing_screen_persistent_id()
    test_missing_screen_contextual_id()
    test_missing_screen_serial_id()
    test_quiet_suppresses_missing_screen_error()
    test_malformed_key_is_rejected()
    test_mode_targeting_syntax_is_parsed()
    test_legacy_res_format_is_parsed()
    test_missing_resolution_on_a_real_screen()

    if failures:
        print(f'\n{len(failures)} check(s) failed:')
        for f in failures:
            print(f'  - {f}')
        sys.exit(1)

    print('\nAll checks passed')


if __name__ == '__main__':
    main()
