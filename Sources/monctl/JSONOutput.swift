import Foundation

/// Pretty-printed JSON to stdout, for every `--json` flag across the CLI.
func printJSON(_ value: some Encodable) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    print(String(bytes: data, encoding: .utf8) ?? "")
}
