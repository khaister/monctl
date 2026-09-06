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
        eprint("Error unsetting mirroring as a prerequisite to applying profiles\n")
        isSuccess = false
    }

    return isSuccess
}

func unsetMirror(_ configRef: CGDisplayConfigRef?, _ mirrorScreenId: CGDirectDisplayID,
                 _ mirrorScreenUUID: String) -> Bool {
    if CGDisplayIsInMirrorSet(mirrorScreenId) != 0,
       CGDisplayMirrorsDisplay(mirrorScreenId) != 0 { // this screen is a secondary screen in a mirroring set
        if CGConfigureDisplayMirrorOfDisplay(configRef, mirrorScreenId, kCGNullDirectDisplay) != .success {
            eprint("Error disabling mirroring on screen \(mirrorScreenUUID)\n")
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
        eprint("Error altering enabled/disabled config\n")
        isSuccess = false
    }

    return isSuccess
}

func setEnabled(_ configRef: CGDisplayConfigRef?, _ screenId: CGDirectDisplayID, _ screenUUID: String,
                _ isEnabled: Bool) -> Bool {
    if isScreenEnabled(screenId) != isEnabled {
        if !configureDisplayEnabled(configRef, screenId, isEnabled) {
            eprint("Error setting screen \(screenUUID) to enabled:\(isEnabled ? "true" : "false")\n")
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
        eprint("Error making the secondary screen \(mirrorScreenUUID) mirror the primary screen \(primaryScreenUUID)\n")
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

        isSuccess = setResolution(
            configRef,
            id,
            config.uuid,
            width: config.width,
            height: config.height,
            hz: config.hz,
            depth: config.depth,
            scaled: config.scaled,
            modeNum: config.modeNum
        ) && isSuccess
    }

    return isSuccess
}

func setResolution(
    _ configRef: CGDisplayConfigRef?,
    _ screenId: CGDirectDisplayID,
    _ screenUUID: String,
    width: Int,
    height: Int,
    hz: Int,
    depth: Int,
    scaled: Bool,
    modeNum: Int
) -> Bool {
    if modeNum != -1 { // user specified modeNum instead of height/width/hz
        _ = configureDisplayMode(configRef, screenId, Int32(modeNum))
        return true
    }

    let modeCount = getDisplayModeCount(screenId)
    var modes: [DisplayMode] = []
    modes.reserveCapacity(Int(modeCount))
    for i in 0 ..< modeCount {
        modes.append(getDisplayMode(screenId, i))
    }

    if let bestMode = selectBestMode(modes, width: width, height: height, hz: hz, depth: depth, scaled: scaled) {
        _ = configureDisplayMode(configRef, screenId, bestMode.mode)
        return true
    }

    var message = "Screen ID \(screenUUID): could not find res:\(width)x\(height)"
    if hz != 0 {
        message += " hz:\(hz)"
    }
    if depth != 0 {
        message += " color_depth:\(depth)"
    }
    message += " scaling:\(scaled ? "on" : "off")\n"
    eprint(message)

    return false
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
        eprint("Error moving screen \(screenUUID) to \(x)x\(y)\n")
        return false
    }

    return true
}
