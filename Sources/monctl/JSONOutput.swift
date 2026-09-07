import Foundation

/// Pretty-printed JSON to stdout, for every `--json` flag across the CLI. `.sortedKeys` is what
/// makes key order deterministic run to run - on this JSONEncoder implementation, leaving it
/// off does *not* fall back to declaration/`encode(to:)` call order, it's effectively random
/// per process (confirmed empirically - a custom `encode(to:)` calling `container.encode`
/// strictly in field order still came out shuffled without `.sortedKeys`). `list --json`'s
/// `modes`-last requirement can't be satisfied through this path at all for that reason - see
/// `renderScreenInfosJSON` in ScreenLister.swift, which builds that one output by hand instead.
func printJSON(_ value: some Encodable) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    print(String(bytes: data, encoding: .utf8) ?? "")
}
