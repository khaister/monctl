import ApplicationServices
import ArgumentParser
import CDisplayCore
import Foundation

struct Monctl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "monctl",
        discussion: helpDiscussion,
        version: versionText,
        subcommands: [List.self, Apply.self],
        defaultSubcommand: Apply.self
    )
}

struct Apply: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apply", shouldDisplay: false)

    @Argument(
        parsing: .remaining,
        help: "One \"key:value key:value ...\" screen config string per screen. Run with no arguments to see the full guide."
    )
    var propGroups: [String] = []

    func run() throws {
        guard !propGroups.isEmpty else {
            print(Monctl.helpMessage())
            return
        }

        var screenConfigs = ScreenConfigParser.parse(propGroups)

        let onlineList = onlineDisplays()

        // If there is only one active screen and no screen id was provided, don't require a screen id and instead
        // default to the only available screen id. Active means the display is not disabled and is not mirroring
        // another display.
        if screenConfigs[0].uuid.isEmpty {
            let activeList = activeDisplays()
            if activeList.count == 1 {
                screenConfigs[0].uuid = uuidString(for: activeList[0])
            }
        }

        var isSuccess =
            true // returns non-zero exit code on any errors but allows for completing remaining program execution

        isSuccess = setEnableds(screenConfigs, onlineList: onlineList) &&
            isSuccess // Enable/disable screens and call CGCompleteDisplayConfiguration as a prereq to applying other
        // config.
        isSuccess = unsetMirrors(screenConfigs, onlineList: onlineList) &&
            isSuccess // Disable all mirroring prior and call CGCompleteDisplayConfiguration as a prereq to ensure displays
        // are in a known starting state.
        isSuccess = setRotations(screenConfigs, onlineList: onlineList) &&
            isSuccess // Set all display rotations as a prereq so the portrait or landscape resolutions can be found when
        // setting the resolutions. Also, disable mirroring after each rotation alteration since macOS will often times
        // oddly auto-enable mirroring when a screen is rotated.

        var configRef: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&configRef) // Share a configRef for the remainder of the program since these configs do
        // not interrupt each other. This reduces the number of screen flashes when running monctl.
        isSuccess = setMirrors(screenConfigs, configRef: configRef, onlineList: onlineList) && isSuccess
        isSuccess = setResolutions(screenConfigs, configRef: configRef, onlineList: onlineList) && isSuccess
        isSuccess = setPositions(
            screenConfigs,
            configRef: configRef,
            onlineList: onlineList,
            screenCount: onlineList.count
        ) && isSuccess

        if CGCompleteDisplayConfiguration(configRef, .permanently) != .success {
            eprint("Error finalizing mirroring, resolutions, and/or positions\n")
            isSuccess = false
        }

        if !isSuccess {
            throw ExitCode.failure
        }
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show current screen info and possible resolutions"
    )

    func run() {
        listScreens()
        printCurrentProfile()
    }
}

Monctl.main()
