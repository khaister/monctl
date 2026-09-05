struct ScreenConfig {
    var uuid: String = ""                    // user input display identifier that stays consistent despite GPU or port changes (persistent screen id)
    var mirrorUUIDs: [String] = []           // user input display UUIDs that mirror this display
    var width: Int = 0                       // pixels wide
    var height: Int = 0                      // pixels tall
    var hz: Int = 0                          // refresh rate
    var depth: Int = 0                       // color depth
    var enabled: Bool = true                 // disables screen from macOS - does not turn screen off, just turns it black
    var scaled: Bool = false                 // scaling
    var x: Int = 0                           // origin x position
    var y: Int = 0                           // origin y position
    var modeNum: Int = -1                    // display mode id
    var degree: Int = 0                      // rotation degree
    var quietMissingScreen: Bool = false     // prevent printing error logs and exiting non-zero when this screen cannot be found
}

let mirrorMax = 127
