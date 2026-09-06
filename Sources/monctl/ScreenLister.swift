import ApplicationServices
import CDisplayCore
import Foundation

func listScreens() {
    for curScreen in onlineDisplays() {
        let curModeId = getCurrentDisplayModeIndex(curScreen)
        let curMode = getDisplayMode(curScreen, curModeId)
        let curScreenUUID = uuidString(for: curScreen)

        print("Persistent screen id: \(curScreenUUID)")
        print("Contextual screen id: \(curScreen)")
        print("Serial screen id: s\(CGDisplaySerialNumber(curScreen))")

        if CGDisplayIsBuiltin(curScreen) != 0 {
            print("Type: MacBook built in screen")
        } else {
            let size = CGDisplayScreenSize(curScreen)
            let diagonal = Int((sqrt(size.width * size.width + size.height * size.height) / 25.4)
                .rounded()) // 25.4mm in an inch
            print("Type: \(diagonal) inch external screen")
        }

        print("Resolution: \(Int(CGDisplayPixelsWide(curScreen)))x\(Int(CGDisplayPixelsHigh(curScreen)))")

        if curMode.freq != 0 {
            print("Hertz: \(curMode.freq)")
        } else {
            print("Hertz: N/A")
        }

        print("Color Depth: \(curMode.depth)")
        print("Scaling: \(curMode.density == 2.0 ? "on" : "off")")

        let origin = CGDisplayBounds(curScreen).origin
        var originLine = "Origin: (\(Int(origin.x)),\(Int(origin.y)))"
        if CGDisplayIsMain(curScreen) != 0 {
            originLine += " - main display"
        }
        print(originLine)

        var rotationLine = "Rotation: \(Int(CGDisplayRotation(curScreen)))"
        if CGDisplayIsBuiltin(curScreen) != 0 {
            // swiftlint:disable:next line_length
            rotationLine += " - rotate internal screen example (may crash computer, but will be rotated after rebooting): `monctl \"id:\(curScreenUUID) degree:90\"`"
        }
        print(rotationLine)

        print("Enabled: \(isScreenEnabled(curScreen) ? "true" : "false")")

        let modeCount = getDisplayModeCount(curScreen)
        print("Resolutions for rotation \(Int(CGDisplayRotation(curScreen))):")
        for j in 0 ..< modeCount {
            let mode = getDisplayMode(curScreen, j)

            var line = "  mode \(j): res:\(mode.width)x\(mode.height)"
            if mode.freq != 0 {
                line += " hz:\(mode.freq)"
            }
            line += " color_depth:\(mode.depth)"
            if mode.density == 2.0 {
                line += " scaling:on"
            }
            if j == curModeId {
                line += " <-- current mode"
            }
            print(line)
        }
        print("")
    }
}

private struct ProfileEntry {
    let id: CGDirectDisplayID
    var mirrors: [CGDirectDisplayID] = []
    var isMirrorOfAnother = false
}

func printCurrentProfile() {
    var entries = onlineDisplays().map { ProfileEntry(id: $0) }

    for i in 0 ..< entries.count {
        let id = entries[i].id
        if CGDisplayIsInMirrorSet(id) != 0,
           CGDisplayMirrorsDisplay(id) != 0 { // this screen is a secondary screen in a mirroring set
            let primaryScreenId = CGDisplayMirrorsDisplay(id)

            for j in 0 ..< entries.count where entries[j].id == primaryScreenId {
                entries[j].mirrors.append(id)
            }

            entries[i].isMirrorOfAnother = true
        }
    }

    print(
        // swiftlint:disable:next line_length
        "Execute the command below to set your screens to the current arrangement. If screen ids are switching, please run `monctl --help` for info on using contextual or serial ids instead of persistent ids.\n"
    )

    var output = "monctl"
    for entry in entries {
        if entry.isMirrorOfAnother { // earlier we marked this since it will be represented as a mirror on output
            continue
        }

        let curScreenUUID = uuidString(for: entry.id)
        let curModeId = getCurrentDisplayModeIndex(entry.id)
        let curMode = getDisplayMode(entry.id, curModeId)
        let enabled = CGDisplayIsActive(entry.id) != 0

        if !enabled {
            output += " \"id:\(curScreenUUID) enabled:false\""
            continue
        }

        var hz = "" // most displays do not have hz option
        if curMode.freq != 0 {
            hz = "hz:\(curMode.freq) "
        }

        let scaling = curMode.density == 2.0 ? "on" : "off"

        var mirrors = ""
        for mirrorId in entry.mirrors {
            mirrors += "+" + uuidString(for: mirrorId)
        }

        let bounds = CGDisplayBounds(entry.id)
        // swiftlint:disable:next line_length
        output += " \"id:\(curScreenUUID)\(mirrors) res:\(Int(CGDisplayPixelsWide(entry.id)))x\(Int(CGDisplayPixelsHigh(entry.id))) \(hz)color_depth:\(curMode.depth) enabled:true scaling:\(scaling) origin:(\(Int(bounds.origin.x)),\(Int(bounds.origin.y))) degree:\(Int(CGDisplayRotation(entry.id)))\""
    }
    print(output)
}
