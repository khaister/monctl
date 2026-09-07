let helpDiscussion = """
monctl configures macOS display resolutions, arrangement, and rotation from the command line.

Examples:
    List connected screens:               monctl list
    See every mode a screen supports:     monctl list --long --screen <id>
    Rotate one screen:                    monctl set --screen <id> --rotate 90
    Place a screen to the right:          monctl set --screen <id> --right-of <otherId>
    Save the current layout:              monctl profile save docked
    Re-apply a saved layout:              monctl profile apply docked

Run `monctl <subcommand> --help` for details on any of the above. See docs/usage.md and
docs/concepts.md (screen id types, origin, modes, mirroring) for the full guide.
"""

let versionText = "v2026.09.06.1"
