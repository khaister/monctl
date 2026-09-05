import ApplicationServices
import CDisplayCore
import Foundation

func run() -> Int32 {
    let arguments = CommandLine.arguments

    if arguments.count == 1 || arguments[1] == "--help" {
        printHelp()
        return 0
    }

    if arguments[1] == "--version" {
        printVersion()
        return 0
    }

    if arguments.count == 3 && arguments[1] == "list" && arguments[2] == "--v1.3.0" {
        listScreens(legacy: true)
        printCurrentProfile(legacy: true)
        return 0
    }

    if arguments[1] == "list" {
        listScreens(legacy: false)
        printCurrentProfile(legacy: false)
        return 0
    }

    var screenConfigs = ArgumentParser.parse(Array(arguments.dropFirst()))

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

    return isSuccess ? 0 : 1
}

exit(run())
