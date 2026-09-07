import ApplicationServices
import CDisplayCore

private func performRotation(_ screenId: CGDirectDisplayID, _ screenUUID: String, _ degree: Int) -> Bool {
    screenUUID.withCString { cUUID in
        setRotation(screenId, cUUID, Int32(degree))
    }
}

func unsetMirrors(_ screenConfigs: [ScreenConfig], onlineList: [CGDirectDisplayID]) -> Bool {
    var configRef: CGDisplayConfigRef?
    CGBeginDisplayConfiguration(&configRef)
    var isSuccess = true

    for config in screenConfigs {
        let id = convertUUIDtoID(config.uuid)
        if !validateScreenOnline(onlineList, id, config.uuid, config.quietMissingScreen) {
            if !config.quietMissingScreen {
                isSuccess = false
            }
            continue
        }

        if !config.enabled {
            continue // screen is disabled, no need to apply other configs for this screen
        }

        for mirrorUUID in config.mirrorUUIDs {
            let mirrorId = convertUUIDtoID(mirrorUUID)
            if !validateScreenOnline(onlineList, mirrorId, mirrorUUID, config.quietMissingScreen) {
                if !config.quietMissingScreen {
                    isSuccess = false
                }
                continue
            }

            isSuccess = unsetMirror(configRef, mirrorId, mirrorUUID) && isSuccess
        }

        isSuccess = unsetMirror(configRef, id, config.uuid) && isSuccess
    }

    if CGCompleteDisplayConfiguration(configRef, .permanently) != .success {
        printError("could not unset mirroring as a prerequisite to applying profiles.")
        isSuccess = false
    }

    return isSuccess
}

func unsetMirror(_ configRef: CGDisplayConfigRef?, _ mirrorScreenId: CGDirectDisplayID,
                 _ mirrorScreenUUID: String) -> Bool {
    if CGDisplayIsInMirrorSet(mirrorScreenId) != 0,
       CGDisplayMirrorsDisplay(mirrorScreenId) != 0 { // this screen is a secondary screen in a mirroring set
        if CGConfigureDisplayMirrorOfDisplay(configRef, mirrorScreenId, kCGNullDirectDisplay) != .success {
            printError("could not disable mirroring on screen \"\(mirrorScreenUUID)\".")
            return false
        }
    }

    return true
}

func setEnableds(_ screenConfigs: [ScreenConfig], onlineList: [CGDirectDisplayID]) -> Bool {
    var configRef: CGDisplayConfigRef?
    CGBeginDisplayConfiguration(&configRef)
    var isSuccess = true

    for config in screenConfigs {
        let id = convertUUIDtoID(config.uuid)
        if !validateScreenOnline(onlineList, id, config.uuid, config.quietMissingScreen) {
            if !config.quietMissingScreen {
                isSuccess = false
            }
            continue
        }

        for mirrorUUID in config.mirrorUUIDs {
            let mirrorId = convertUUIDtoID(mirrorUUID)
            if !validateScreenOnline(onlineList, mirrorId, mirrorUUID, config.quietMissingScreen) {
                if !config.quietMissingScreen {
                    isSuccess = false
                }
                continue
            }

            isSuccess = setEnabled(configRef, mirrorId, mirrorUUID, config.enabled) && isSuccess
        }

        isSuccess = setEnabled(configRef, id, config.uuid, config.enabled) && isSuccess
    }

    if CGCompleteDisplayConfiguration(configRef, .permanently) != .success {
        printError("could not finalize enabled/disabled changes.")
        isSuccess = false
    }

    return isSuccess
}

func setEnabled(_ configRef: CGDisplayConfigRef?, _ screenId: CGDirectDisplayID, _ screenUUID: String,
                _ isEnabled: Bool) -> Bool {
    if isScreenEnabled(screenId) != isEnabled {
        if !configureDisplayEnabled(configRef, screenId, isEnabled) {
            printError("could not set screen \"\(screenUUID)\" to enabled:\(isEnabled ? "true" : "false").")
            return false
        }
    }

    return true
}

func setRotations(_ screenConfigs: [ScreenConfig], onlineList: [CGDirectDisplayID]) -> Bool {
    var isSuccess = true

    for config in screenConfigs {
        let id = convertUUIDtoID(config.uuid)
        if !validateScreenOnline(onlineList, id, config.uuid, config.quietMissingScreen) {
            if !config.quietMissingScreen {
                isSuccess = false
            }
            continue
        }

        if !config.enabled {
            continue // screen is disabled, no need to apply other configs for this screen
        }

        for mirrorUUID in config.mirrorUUIDs {
            let mirrorId = convertUUIDtoID(mirrorUUID)
            if !validateScreenOnline(onlineList, mirrorId, mirrorUUID, config.quietMissingScreen) {
                if !config.quietMissingScreen {
                    isSuccess = false
                }
                continue
            }

            if Int(CGDisplayRotation(mirrorId)) != config.degree {
                isSuccess = performRotation(mirrorId, mirrorUUID, config.degree) && isSuccess
                isSuccess = unsetMirrors(screenConfigs, onlineList: onlineList) && isSuccess
            }
        }

        if Int(CGDisplayRotation(id)) != config.degree {
            isSuccess = performRotation(id, config.uuid, config.degree) && isSuccess
            isSuccess = unsetMirrors(screenConfigs, onlineList: onlineList) && isSuccess
        }
    }

    return isSuccess
}

func setMirrors(_ screenConfigs: [ScreenConfig], configRef: CGDisplayConfigRef?,
                onlineList: [CGDirectDisplayID]) -> Bool {
    var isSuccess = true

    for config in screenConfigs {
        let id = convertUUIDtoID(config.uuid)
        if !validateScreenOnline(onlineList, id, config.uuid, config.quietMissingScreen) {
            if !config.quietMissingScreen {
                isSuccess = false
            }
            continue
        }

        if !config.enabled {
            continue // screen is disabled, no need to apply other configs for this screen
        }

        for mirrorUUID in config.mirrorUUIDs {
            let mirrorId = convertUUIDtoID(mirrorUUID)
            if !validateScreenOnline(onlineList, mirrorId, mirrorUUID, config.quietMissingScreen) {
                if !config.quietMissingScreen {
                    isSuccess = false
                }
                continue
            }

            isSuccess = setMirror(configRef, id, config.uuid, mirrorId, mirrorUUID) && isSuccess
        }
    }

    return isSuccess
}

func setMirror(
    _ configRef: CGDisplayConfigRef?,
    _ primaryScreenId: CGDirectDisplayID,
    _ primaryScreenUUID: String,
    _ mirrorScreenId: CGDirectDisplayID,
    _ mirrorScreenUUID: String
) -> Bool {
    if CGConfigureDisplayMirrorOfDisplay(configRef, mirrorScreenId, primaryScreenId) != .success {
        printError("could not make screen \"\(mirrorScreenUUID)\" mirror screen \"\(primaryScreenUUID)\".")
        return false
    }

    return true
}

func setResolutions(_ screenConfigs: [ScreenConfig], configRef: CGDisplayConfigRef?,
                    onlineList: [CGDirectDisplayID]) -> Bool {
    var isSuccess = true

    for config in screenConfigs {
        let id = convertUUIDtoID(config.uuid)
        if !validateScreenOnline(onlineList, id, config.uuid, config.quietMissingScreen) {
            if !config.quietMissingScreen {
                isSuccess = false
            }
            continue
        }

        if !config.enabled {
            continue // screen is disabled, no need to apply other configs for this screen
        }

        isSuccess = setResolution(configRef, id, config.uuid, config) && isSuccess
    }

    return isSuccess
}

/// Resolves what `setResolution` would end up applying, without applying it - either the exact
/// mode `config.modeNum` points at, or (when `config.modeNum == -1`) whatever
/// `selectBestMode` picks for `config`'s width/height/hz/depth/scaled. `nil` means no mode
/// matches. Used both by the real apply (`setResolution`) and by `set --dry-run`, so a preview
/// reports the same match-or-fail outcome (and the same concrete hz/depth/scaling a wildcarded
/// 0 resolves to) that actually applying would.
func findMatchingMode(_ screenId: CGDirectDisplayID, _ config: ScreenConfig) -> DisplayMode? {
    if config.modeNum != -1 {
        return getDisplayMode(screenId, Int32(config.modeNum))
    }

    let modeCount = getDisplayModeCount(screenId)
    var modes: [DisplayMode] = []
    modes.reserveCapacity(Int(modeCount))
    for i in 0 ..< modeCount {
        modes.append(getDisplayMode(screenId, i))
    }

    return selectBestMode(
        modes,
        width: config.width,
        height: config.height,
        hz: config.hz,
        depth: config.depth,
        scaled: config.scaled
    )
}

func printNoMatchingModeError(screenUUID: String, config: ScreenConfig) {
    var message = "no mode on screen \"\(screenUUID)\" matches resolution \(config.width)x\(config.height)"
    if config.hz != 0 {
        message += " hz:\(config.hz)"
    }
    if config.depth != 0 {
        message += " depth:\(config.depth)"
    }
    message += " scaling:\(config.scaled ? "on" : "off"). Run 'monctl list --long --screen \(screenUUID)' to see available modes."
    printError(message)
}

func setResolution(
    _ configRef: CGDisplayConfigRef?,
    _ screenId: CGDirectDisplayID,
    _ screenUUID: String,
    _ config: ScreenConfig
) -> Bool {
    guard let bestMode = findMatchingMode(screenId, config) else {
        printNoMatchingModeError(screenUUID: screenUUID, config: config)
        return false
    }

    _ = configureDisplayMode(configRef, screenId, bestMode.mode)
    return true
}

/// Finds the mode in `modes` that best matches the required width/height and optional
/// hz/depth/scaled filters (hz==0 and depth==0 mean "any"). Among matches, prefers the
/// highest hz, then the highest color depth. Ported from `selectBestMode` in the old
/// src/Header.h (verified byte-identical against Tests/Unit/test_mode_selection.c's cases).
func selectBestMode(_ modes: [DisplayMode], width: Int, height: Int, hz: Int, depth: Int,
                    scaled: Bool) -> DisplayMode? {
    var bestMode: DisplayMode?

    for curMode in modes {
        // prioritize exact matches of user input params
        if Int(curMode.width) != width {
            continue
        }
        if Int(curMode.height) != height {
            continue
        }
        if hz != 0 && Int(curMode.freq) != hz {
            continue
        }
        if depth != 0 && Int(curMode.depth) != depth {
            continue
        }
        if scaled && curMode.density != 2.0 {
            continue
        }
        if !scaled && curMode.density == 2.0 {
            continue
        }

        if bestMode == nil {
            bestMode = curMode
        }

        if curMode.freq > bestMode!.freq || (curMode.freq == bestMode!.freq && curMode.depth > bestMode!.depth) {
            bestMode = curMode
        }
    }

    return bestMode
}

func setPositions(
    _ screenConfigs: [ScreenConfig],
    configRef: CGDisplayConfigRef?,
    onlineList: [CGDirectDisplayID],
    screenCount: Int
) -> Bool {
    var isSuccess = true

    for config in screenConfigs {
        let id = convertUUIDtoID(config.uuid)
        if !validateScreenOnline(onlineList, id, config.uuid, config.quietMissingScreen) {
            if !config.quietMissingScreen {
                isSuccess = false
            }
            continue
        }

        if !config.enabled {
            continue // screen is disabled, no need to apply other configs for this screen
        }

        let curOrigin = CGDisplayBounds(id).origin
        // setting a screen to its current origin makes monctl hang for a couple seconds. If there is
        // only one screen, macOS will force the origin to be (0,0) so we do not need to set it.
        if Int(curOrigin.x) != config.x || Int(curOrigin.y) != config.y, screenCount > 1 {
            isSuccess = setPosition(configRef, id, config.uuid, config.x, config.y) && isSuccess
        }
    }

    return isSuccess
}

func setPosition(
    _ configRef: CGDisplayConfigRef?,
    _ screenId: CGDirectDisplayID,
    _ screenUUID: String,
    _ x: Int,
    _ y: Int
) -> Bool {
    if CGConfigureDisplayOrigin(configRef, screenId, Int32(x), Int32(y)) != .success {
        printError("could not move screen \"\(screenUUID)\" to (\(x),\(y)).")
        return false
    }

    return true
}

/// Applies a full set of screen configs atomically. Mirrors the staged order the original
/// single-string `apply` command used: enable/disable, unset mirrors, and rotate each as their
/// own prerequisite completions, then mirror/resize/reposition in one shared
/// `CGDisplayConfigRef`, finished by a single `CGCompleteDisplayConfiguration` call. Used by
/// both `set` (a one-element array) and `profile apply` (the whole saved layout).
func applyScreenConfigs(_ screenConfigs: [ScreenConfig]) -> Bool {
    let onlineList = onlineDisplays()
    var isSuccess = true

    isSuccess = setEnableds(screenConfigs, onlineList: onlineList) && isSuccess
    isSuccess = unsetMirrors(screenConfigs, onlineList: onlineList) && isSuccess
    isSuccess = setRotations(screenConfigs, onlineList: onlineList) && isSuccess

    var configRef: CGDisplayConfigRef?
    CGBeginDisplayConfiguration(&configRef)
    isSuccess = setMirrors(screenConfigs, configRef: configRef, onlineList: onlineList) && isSuccess
    isSuccess = setResolutions(screenConfigs, configRef: configRef, onlineList: onlineList) && isSuccess
    isSuccess = setPositions(
        screenConfigs,
        configRef: configRef,
        onlineList: onlineList,
        screenCount: onlineList.count
    ) && isSuccess

    if CGCompleteDisplayConfiguration(configRef, .permanently) != .success {
        printError("could not finalize mirroring, resolutions, and/or positions.")
        isSuccess = false
    }

    return isSuccess
}
