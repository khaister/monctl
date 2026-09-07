import Foundation

/// One field in `list --long`'s per-screen summary block (the part above `Modes:`).
enum LongField: String, Codable, CaseIterable {
    case persistentId
    case contextualId
    case serialId
    case type
    case resolution
    case hz
    case depth
    case scaling
    case origin
    case rotation
    case enabled

    var defaultLabel: String {
        switch self {
        case .persistentId: "Persistent id"
        case .contextualId: "Contextual id"
        case .serialId: "Serial id"
        case .type: "Type"
        case .resolution: "Resolution"
        case .hz: "Hz"
        case .depth: "Color Depth"
        case .scaling: "Scaling"
        case .origin: "Origin"
        case .rotation: "Rotation"
        case .enabled: "Enabled"
        }
    }

    func value(for info: ScreenInfo) -> String {
        switch self {
        case .persistentId: info.persistentID
        case .contextualId: "\(info.contextualID)"
        case .serialId: info.serialID
        case .type: info.typeDescription
        case .resolution: "\(info.width)x\(info.height)"
        case .hz: info.hz != 0 ? "\(info.hz)" : "N/A"
        case .depth: "\(info.depth)"
        case .scaling: info.scaling ? "on" : "off"
        case .origin: "(\(info.originX),\(info.originY))"
        case .rotation: "\(info.rotation)"
        case .enabled: "\(info.enabled)"
        }
    }
}

/// One entry in a `listLongFields` override (config file or `$MONCTL_LIST_LONG_FIELDS`). `label`
/// is optional per entry so a user can override just the order/visibility of fields without
/// having to retype every label.
struct LongFieldConfig: Codable, Equatable {
    var key: LongField
    var label: String?

    func resolvedLabel() -> String {
        label ?? key.defaultLabel
    }
}

/// The base directory monctl's own files live under: `$XDG_CONFIG_HOME/monctl` if that's set
/// (and non-empty), else `~/.config/monctl`. This can only ever be an environment variable -
/// it's what locates `config.json` itself, so it can't also be a key inside that file.
func monctlConfigDirectory() -> URL {
    let configHome: String = if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
        xdg
    } else {
        NSHomeDirectory() + "/.config"
    }
    return URL(fileURLWithPath: configHome).appendingPathComponent("monctl")
}

/// The raw contents of `~/.config/monctl/config.json`. Every field mirrors one of `Settings`'
/// properties and is optional - see `Settings.resolve()` for how a config file value, its
/// environment variable counterpart, and a built-in default combine into the value actually
/// used at runtime.
struct MonctlConfig: Codable, Equatable {
    var listLongFields: [LongFieldConfig]?
    var pager: String?
    var disablePager: Bool?
    var noColor: Bool?
    var editor: String?
    var profileApplyNoConfirm: Bool?

    static let empty = MonctlConfig()

    static var path: URL {
        monctlConfigDirectory().appendingPathComponent("config.json")
    }

    /// Falls back to every default (`MonctlConfig.empty`) if the file doesn't exist; warns and
    /// falls back the same way if it exists but fails to parse, rather than breaking every
    /// command over a config typo.
    static func load() -> MonctlConfig {
        guard let data = try? Data(contentsOf: path) else {
            return .empty
        }
        do {
            return try JSONDecoder().decode(MonctlConfig.self, from: data)
        } catch {
            printWarning("could not parse \(path.path): \(error.localizedDescription). Using defaults.")
            return .empty
        }
    }
}

/// Every monctl setting, resolved once per invocation. For each one: an environment variable,
/// when set, always wins; otherwise the config file's value is used; otherwise a built-in
/// default. Access via `Settings.current`, which resolves lazily on first use and is memoized
/// for the rest of the process's lifetime.
struct Settings {
    let longFields: [LongFieldConfig]
    let pager: String
    let disablePager: Bool
    let noColor: Bool
    let editor: String
    let profileApplyNoConfirm: Bool

    static let current = resolve()

    private static func resolve() -> Settings {
        let env = ProcessInfo.processInfo.environment
        let config = MonctlConfig.load()

        return Settings(
            longFields: env["MONCTL_LIST_LONG_FIELDS"].flatMap(parseLongFieldsEnv)
                ?? config.listLongFields
                ?? LongField.allCases.map { LongFieldConfig(key: $0, label: nil) },
            pager: env["PAGER"] ?? config.pager ?? "less",
            disablePager: envFlag(env["MONCTL_DISABLE_PAGER"]) ?? config.disablePager ?? false,
            // NO_COLOR's mere presence (any value) disables color per no-color.org - there's no
            // "force color back on" counterpart, so this is effectively already "env wins when
            // defined", just expressed as an OR against the config file's noColor.
            noColor: env["NO_COLOR"] != nil || (config.noColor ?? false),
            editor: env["EDITOR"] ?? config.editor ?? "vi",
            profileApplyNoConfirm: envFlag(env["MONCTL_PROFILE_APPLY_NO_CONFIRM"]) ?? config
                .profileApplyNoConfirm ?? false
        )
    }
}

/// `nil` when `raw` is unset (so the caller falls through to the config file); otherwise `true`
/// for `"1"` or `"true"` (case-insensitive), matching the boolean config keys' JSON `true`.
private func envFlag(_ raw: String?) -> Bool? {
    raw.map { $0 == "1" || $0.lowercased() == "true" }
}

/// Parses `$MONCTL_LIST_LONG_FIELDS`: a comma-separated list of `key` or `key:label` tokens,
/// e.g. `"type,resolution,hz,depth:Depth,scaling,enabled"`. Returns `nil` (falling through to
/// the config file/default) if `raw` contains no recognized field.
private func parseLongFieldsEnv(_ raw: String) -> [LongFieldConfig]? {
    let fields: [LongFieldConfig] = raw.split(separator: ",").compactMap { token in
        let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
        let rawKey = parts[0].trimmingCharacters(in: .whitespaces)
        guard let key = LongField(rawValue: rawKey) else {
            printWarning("unknown list-long field \"\(rawKey)\" in $MONCTL_LIST_LONG_FIELDS - ignoring it.")
            return nil
        }
        return LongFieldConfig(key: key, label: parts.count > 1 ? parts[1] : nil)
    }
    return fields.isEmpty ? nil : fields
}
