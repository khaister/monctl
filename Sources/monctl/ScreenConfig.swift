/// A single screen's full desired (or current) state: everything `set` can change on one
/// screen, and everything a saved profile snapshots per screen.
struct ScreenConfig: Codable, Equatable {
    var uuid: String = "" // persistent screen id (or whichever id type the user passed in)
    var mirrorUUIDs: [String] = [] // ids of screens mirroring this one
    var width: Int = 0 // pixels wide
    var height: Int = 0 // pixels tall
    var hz: Int = 0 // refresh rate
    var depth: Int = 0 // color depth
    var enabled: Bool = true // disables screen from macOS - does not turn screen off, just turns it black
    var scaled: Bool = false // scaling
    var x: Int = 0 // origin x position
    var y: Int = 0 // origin y position
    var modeNum: Int = -1 // display mode id, -1 means "use width/height/hz/depth/scaled instead"
    var degree: Int = 0 // rotation degree
    var quietMissingScreen: Bool =
        false // prevent printing error logs and exiting non-zero when this screen cannot be found

    enum CodingKeys: String, CodingKey {
        case uuid = "id"
        case mirrorUUIDs = "mirrors"
        case width
        case height
        case hz
        case depth
        case enabled
        case scaled = "scaling"
        case x
        case y
        case modeNum = "mode"
        case degree = "rotate"
        case quietMissingScreen = "quiet"
    }
}

let mirrorMax = 127
