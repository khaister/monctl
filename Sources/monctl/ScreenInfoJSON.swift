import Foundation

/// `ScreenInfo` minus `modes` - encoded separately from it so `modes` (by far the bulkiest
/// field) can be spliced back in last. See `renderScreenInfosJSON`.
private struct ScreenInfoScalars: Encodable {
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

    init(_ info: ScreenInfo) {
        persistentID = info.persistentID
        contextualID = info.contextualID
        serialID = info.serialID
        isMain = info.isMain
        isBuiltin = info.isBuiltin
        typeDescription = info.typeDescription
        width = info.width
        height = info.height
        hz = info.hz
        depth = info.depth
        scaling = info.scaling
        originX = info.originX
        originY = info.originY
        rotation = info.rotation
        enabled = info.enabled
    }
}

private let screenInfoJSONEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
}()

private func jsonText(_ value: some Encodable) -> String {
    (try? screenInfoJSONEncoder.encode(value)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "null"
}

/// Adds `spaces` spaces to the start of every line in `text`.
private func reindentAllLines(_ text: String, by spaces: Int) -> String {
    let pad = String(repeating: " ", count: spaces)
    return text.components(separatedBy: "\n").map { pad + $0 }.joined(separator: "\n")
}

/// Adds `spaces` spaces to the start of every line in `text` except the first - for a fragment
/// about to be placed right after `"key" : `, where the first line already sits at the right
/// column (attached to the key) and only its wrapped continuation lines need to be pushed in.
private func reindentContinuationLines(_ text: String, by spaces: Int) -> String {
    let pad = String(repeating: " ", count: spaces)
    var lines = text.components(separatedBy: "\n")
    guard lines.count > 1 else { return text }
    for i in 1 ..< lines.count {
        lines[i] = pad + lines[i]
    }
    return lines.joined(separator: "\n")
}

/// `list --json`'s `[ScreenInfo]` output, built by hand rather than through the usual
/// `printJSON` path: every field is alphabetized via `.sortedKeys`, as everywhere else in
/// monctl's JSON output, *except* `modes` - which is spliced in last, after every scalar field,
/// since a plain `Encodable` conformance has no way to pin one field's position on this
/// `JSONEncoder` (see `printJSON`'s doc comment for why - key order without `.sortedKeys` isn't
/// declaration order, it's effectively random).
func renderScreenInfosJSON(_ infos: [ScreenInfo]) -> String {
    guard !infos.isEmpty else { return "[]" }

    let objects = infos.map { info -> String in
        let scalarsText = jsonText(ScreenInfoScalars(info))
        let modesValue = reindentContinuationLines(jsonText(info.modes), by: 2)

        // A non-empty ScreenInfoScalars object always pretty-prints ending in "\n}" - splice
        // the modes field in right before that closing brace.
        guard scalarsText.hasSuffix("\n}") else { return reindentAllLines(scalarsText, by: 2) }
        let withModes = String(scalarsText.dropLast(2)) + ",\n  \"modes\" : \(modesValue)\n}"

        return reindentAllLines(withModes, by: 2)
    }

    return "[\n" + objects.joined(separator: ",\n") + "\n]"
}
