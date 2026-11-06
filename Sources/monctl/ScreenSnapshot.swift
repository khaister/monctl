import ApplicationServices
import CDisplayCore
import Foundation

struct ScreenModeInfo: Codable, Equatable {
    var modeNum: Int
    var width: Int
    var height: Int
    var hz: Int
    var depth: Int
    var scaling: Bool
    var isCurrent: Bool
}

/// Everything `list`/`list --long`/`list --json` can show about one screen. Field-for-field,
/// this is a superset of `ScreenConfig`: it also carries the ids/type/mode-list that are only
/// ever read, never set.
struct ScreenInfo: Codable {
    var persistentID: String
    var contextualID: UInt32
    var serialID: String
    var isMain: Bool
    var isBuiltin: Bool
    var typeDescription: String
    var width: Int
    var height: Int
    var hz: Int
    var depth: Int
    var scaling: Bool
    var originX: Int
    var originY: Int
    var rotation: Int
    var enabled: Bool
    var modes: [ScreenModeInfo]
}

func typeDescription(for screen: CGDirectDisplayID) -> String {
    if CGDisplayIsBuiltin(screen) != 0 {
        return "built-in"
    }
    let size = CGDisplayScreenSize(screen)
    let diagonal = Int((sqrt(size.width * size.width + size.height * size.height) / 25.4).rounded()) // 25.4mm/inch
    return "\(diagonal)in external"
}

func allModes(for screen: CGDirectDisplayID) -> [ScreenModeInfo] {
    let curModeId = getCurrentDisplayModeIndex(screen)
    let modeCount = getDisplayModeCount(screen)
    var modes: [ScreenModeInfo] = []
    modes.reserveCapacity(Int(modeCount))
    for i in 0 ..< modeCount {
        let mode = getDisplayMode(screen, i)
        modes.append(ScreenModeInfo(
            modeNum: Int(i),
            width: Int(mode.width),
            height: Int(mode.height),
            hz: Int(mode.freq),
            depth: Int(mode.depth),
            scaling: mode.density == 2.0,
            isCurrent: i == curModeId
        ))
    }
    return modes
}

/// `includeModes` is false for the compact `list` table, which never needs the per-mode dump.
func gatherScreenInfo(_ screen: CGDirectDisplayID, includeModes: Bool) -> ScreenInfo {
    let curModeId = getCurrentDisplayModeIndex(screen)
    let curMode = getDisplayMode(screen, curModeId)
    let origin = CGDisplayBounds(screen).origin

    return ScreenInfo(
        persistentID: uuidString(for: screen),
        contextualID: screen,
        serialID: "s\(CGDisplaySerialNumber(screen))",
        isMain: CGDisplayIsMain(screen) != 0,
        isBuiltin: CGDisplayIsBuiltin(screen) != 0,
        typeDescription: typeDescription(for: screen),
        width: Int(CGDisplayPixelsWide(screen)),
        height: Int(CGDisplayPixelsHigh(screen)),
        hz: Int(curMode.freq),
        depth: Int(curMode.depth),
        scaling: curMode.density == 2.0,
        originX: Int(origin.x),
        originY: Int(origin.y),
        rotation: Int(CGDisplayRotation(screen)),
        enabled: isScreenEnabled(screen),
        modes: includeModes ? allModes(for: screen) : []
    )
}

/// The full current state of `screen`, in the same shape `set` and saved profiles use, so a
/// snapshot can be diffed against a target `ScreenConfig` field-by-field. `uuid` is always the
/// persistent id, regardless of what id type the caller used to look `screen` up, since that's
/// the form that survives being written out to a profile file and re-applied later.
func currentScreenConfig(for screen: CGDirectDisplayID, mirrorUUIDs: [String] = []) -> ScreenConfig {
    let curModeId = getCurrentDisplayModeIndex(screen)
    let curMode = getDisplayMode(screen, curModeId)
    let origin = CGDisplayBounds(screen).origin

    return ScreenConfig(
        uuid: uuidString(for: screen),
        mirrorUUIDs: mirrorUUIDs,
        width: Int(CGDisplayPixelsWide(screen)),
        height: Int(CGDisplayPixelsHigh(screen)),
        hz: Int(curMode.freq),
        depth: Int(curMode.depth),
        enabled: CGDisplayIsActive(screen) != 0,
        scaled: curMode.density == 2.0,
        x: Int(origin.x),
        y: Int(origin.y),
        modeNum: -1,
        degree: Int(CGDisplayRotation(screen)),
        quietMissingScreen: false
    )
}

/// Groups `onlineDisplays()` into "primary" screens (in save/apply order) plus the mirror ids
/// riding along with each one, mirroring `printCurrentProfile`'s old grouping so `profile save`
/// reconstructs `mirrorUUIDs` instead of saving each mirrored screen as its own top-level entry.
func groupedForProfile() -> [(primary: CGDirectDisplayID, mirrors: [CGDirectDisplayID])] {
    let screens = onlineDisplays()
    var mirrorsOf: [CGDirectDisplayID: [CGDirectDisplayID]] = [:]
    var isMirror: Set<CGDirectDisplayID> = []

    for screen in screens where CGDisplayIsInMirrorSet(screen) != 0 && CGDisplayMirrorsDisplay(screen) != 0 {
        let primary = CGDisplayMirrorsDisplay(screen)
        mirrorsOf[primary, default: []].append(screen)
        isMirror.insert(screen)
    }

    return screens.filter { !isMirror.contains($0) }.map { ($0, mirrorsOf[$0] ?? []) }
}
