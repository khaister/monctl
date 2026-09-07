import Foundation

/// Saved layouts live as human-editable JSON under `~/.config/monctl/profiles/<name>.json`
/// (XDG-style, §4.1), one `[ScreenConfig]` array per file.
enum ProfileStore {
    static var directory: URL {
        monctlConfigDirectory().appendingPathComponent("profiles")
    }

    static func path(for name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }

    static func exists(name: String) -> Bool {
        FileManager.default.fileExists(atPath: path(for: name).path)
    }

    static func save(_ configs: [ScreenConfig], name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configs).write(to: path(for: name))
    }

    static func load(name: String) throws -> [ScreenConfig] {
        let data = try Data(contentsOf: path(for: name))
        return try JSONDecoder().decode([ScreenConfig].self, from: data)
    }

    static func remove(name: String) throws {
        try FileManager.default.removeItem(at: path(for: name))
    }

    /// Saved profile names, sorted, or `[]` if the profiles directory doesn't exist yet.
    static func list() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return files.filter { $0.hasSuffix(".json") }.map { String($0.dropLast(".json".count)) }.sorted()
    }
}
