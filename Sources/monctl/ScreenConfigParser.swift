import Foundation

enum ScreenConfigParser {
    /// Ports MonCtl.c's `main()` argument-parsing loop: each element of
    /// `propGroups` is one screen's `key:value key:value ...` string.
    static func parse(_ propGroups: [String]) -> [ScreenConfig] {
        propGroups.map { parseOne($0) }
    }

    private static func parseOne(_ propGroup: String) -> ScreenConfig {
        var config = ScreenConfig()

        for propSetToken in tokenize(propGroup, delimiters: [" ", "\t"]) {
            let (key, value) = splitFirst(propSetToken, on: ":")
            guard let firstChar = key.first else {
                eprint("Argument parsing error\n")
                exit(1)
            }

            switch firstChar {
            case "i": // id
                let idParts = tokenize(value ?? "", delimiters: ["+"])
                config.uuid = idParts.first ?? ""

                var mirrorUUIDs: [String] = []
                for (j, mirrorUUID) in idParts.dropFirst().enumerated() {
                    mirrorUUIDs.append(mirrorUUID)
                    if j + 1 > mirrorMax {
                        eprint(
                            "monctl only supports mirroring up to 128 screens.\n"
                        )
                    }
                }
                config.mirrorUUIDs = mirrorUUIDs

            case "r": // res
                let resParts = tokenize(value ?? "", delimiters: ["x"])
                config.width = catoi(resParts.count > 0 ? resParts[0] : nil)
                config.height = catoi(resParts.count > 1 ? resParts[1] : nil)
                // backward compatability with legacy hz format "res:3840x2160x60"
                if resParts.count > 2 {
                    config.hz = catoi(resParts[2])
                }

            case "h": // hertz
                config.hz = catoi(value)

            case "c": // color_depth
                config.depth = catoi(value)

            case "e": // enabled
                if value == "false" {
                    config.enabled = false
                }

            case "s": // scaling
                config.scaled = (value == "on")

            case "o": // origin
                let originParts = tokenize(value ?? "", delimiters: [","])
                if originParts.count > 0 {
                    config.x = catoi(String(originParts[0].dropFirst())) // skip the '(' character
                }
                if originParts.count > 1 {
                    config.y = catoi(originParts[1])
                }

            case "m": // mode
                config.modeNum = catoi(value)

            case "d": // rotation degree
                config.degree = catoi(value)

            case "q": // quiet
                if value == "true" {
                    config.quietMissingScreen = true
                }

            default:
                eprint("Argument parsing error\n")
                exit(1)
            }
        }

        return config
    }
}
