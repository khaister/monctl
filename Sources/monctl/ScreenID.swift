import ApplicationServices
import Foundation

func onlineDisplays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    CGGetOnlineDisplayList(UInt32(Int32.max), nil, &count)
    var list = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetOnlineDisplayList(UInt32(Int32.max), &list, &count)
    return list
}

func activeDisplays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    CGGetActiveDisplayList(UInt32(Int32.max), nil, &count)
    var list = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(UInt32(Int32.max), &list, &count)
    return list
}

func uuidString(for display: CGDirectDisplayID) -> String {
    guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue() else {
        return ""
    }
    return CFUUIDCreateString(kCFAllocatorDefault, cfUUID) as String
}

func isScreenEnabled(_ screenId: CGDirectDisplayID) -> Bool {
    CGDisplayIsActive(screenId) != 0 || CGDisplayIsInMirrorSet(screenId) != 0
}

func convertUUIDtoID(_ uuid: String) -> CGDirectDisplayID {
    if uuid.contains("s") { // serial screen id starts with "s", for example "s4123456789"
        return convertSerialToID(uuid)
    }

    if !uuid.contains("-") { // contextual screen id is just an integer
        return CGDirectDisplayID(catoi(uuid))
    }

    // uuid contains "-" but does not contain "s" since it is hexadecimal
    guard let cfUUID = CFUUIDCreateFromString(kCFAllocatorDefault, uuid as CFString) else {
        return 0
    }
    return CGDisplayGetDisplayIDFromUUID(cfUUID)
}

func convertSerialToID(_ serialIdString: String) -> CGDirectDisplayID {
    let serialId = UInt32(bitPattern: Int32(catoi(String(serialIdString.dropFirst())))) // "s4123456789" -> 4123456789

    for curScreen in onlineDisplays() {
        if CGDisplaySerialNumber(curScreen) == serialId {
            return curScreen
        }
    }

    eprint("Error converting serialId \(serialIdString) to a screenId\n")
    return 0
}

func validateScreenOnline(
    _ onlineDisplayList: [CGDirectDisplayID],
    _ screenId: CGDirectDisplayID,
    _ screenUUID: String,
    _ quietMissingScreen: Bool
) -> Bool {
    if onlineDisplayList.contains(screenId) {
        return true
    }

    if !quietMissingScreen {
        eprint("Unable to find screen \(screenUUID) - skipping changes for that screen\n") // TODO: only print once per screen
    }
    return false
}
