/// One changed field between a screen's current state and a target `ScreenConfig`, e.g.
/// `rotate: 0 -> 90`. Used by both `set --dry-run` and `profile apply`'s diff/confirmation.
struct FieldDiff {
    let name: String
    let oldValue: String
    let newValue: String

    /// Rendered as `git diff` colors it: old value dim, new value green (§5).
    func rendered(colorEnabled: Bool) -> String {
        let old = colorize(oldValue, .dim, enabled: colorEnabled)
        let new = colorize(newValue, .green, enabled: colorEnabled)
        return "\(name): \(old) -> \(new)"
    }
}

/// Compares every field `set`/`profile apply` can change and returns only the ones that
/// differ. `target` is assumed to already equal `current` for anything the caller didn't
/// explicitly ask to change (see `currentScreenConfig` + flag overlay in `Set.run()`), so a
/// plain field-by-field comparison is sufficient - no need to know which flags were passed.
func diffScreenConfig(current: ScreenConfig, target: ScreenConfig) -> [FieldDiff] {
    var diffs: [FieldDiff] = []

    if current.enabled != target.enabled {
        diffs.append(FieldDiff(name: "enabled", oldValue: "\(current.enabled)", newValue: "\(target.enabled)"))
    }
    if !target.enabled {
        return diffs // a disabled screen's other fields don't matter
    }

    if current.width != target.width || current.height != target.height {
        diffs.append(FieldDiff(
            name: "resolution",
            oldValue: "\(current.width)x\(current.height)",
            newValue: "\(target.width)x\(target.height)"
        ))
    }
    if current.hz != target.hz {
        diffs.append(FieldDiff(name: "hz", oldValue: "\(current.hz)", newValue: "\(target.hz)"))
    }
    if current.depth != target.depth {
        diffs.append(FieldDiff(name: "depth", oldValue: "\(current.depth)", newValue: "\(target.depth)"))
    }
    if current.scaled != target.scaled {
        diffs.append(FieldDiff(
            name: "scaling",
            oldValue: current.scaled ? "on" : "off",
            newValue: target.scaled ? "on" : "off"
        ))
    }
    if current.x != target.x || current.y != target.y {
        diffs.append(FieldDiff(
            name: "origin",
            oldValue: "(\(current.x),\(current.y))",
            newValue: "(\(target.x),\(target.y))"
        ))
    }
    if current.degree != target.degree {
        diffs.append(FieldDiff(name: "rotate", oldValue: "\(current.degree)", newValue: "\(target.degree)"))
    }
    if Set(current.mirrorUUIDs) != Set(target.mirrorUUIDs) {
        diffs.append(FieldDiff(
            name: "mirrors",
            oldValue: current.mirrorUUIDs.isEmpty ? "none" : current.mirrorUUIDs.joined(separator: ","),
            newValue: target.mirrorUUIDs.isEmpty ? "none" : target.mirrorUUIDs.joined(separator: ",")
        ))
    }

    return diffs
}

func renderDiffLine(prefix: String, diffs: [FieldDiff], colorEnabled: Bool) -> String {
    guard !diffs.isEmpty else {
        return "\(prefix): no change"
    }
    return "\(prefix): " + diffs.map { $0.rendered(colorEnabled: colorEnabled) }.joined(separator: ", ")
}
