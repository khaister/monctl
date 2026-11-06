import Foundation

#if canImport(Glibc)
    import Glibc
#else
    import Darwin
#endif

/// `eprint`/`printError`/`printWarning` check only the raw `NO_COLOR` env var, not the full
/// `Settings.current.noColor` (which also folds in the config file) - `printWarning` is itself
/// called while `Settings.current` is still being resolved (a bad config file, or an unknown
/// `$MONCTL_LIST_LONG_FIELDS` entry, both warn from inside that resolution), and reading
/// `Settings.current` from within its own initializer would deadlock/crash.
private func stderrColorForceDisabled() -> Bool {
    ProcessInfo.processInfo.environment["NO_COLOR"] != nil
}

/// Writes `s` to stderr, colored red per §5's "errors are red" convention.
func eprint(_ s: String) {
    let colored = colorize(
        s,
        .red,
        enabled: colorEnabled(forceDisabled: stderrColorForceDisabled(), fd: fileno(stderr))
    )
    FileHandle.standardError.write(colored.data(using: .utf8)!)
}

/// A single-line, `Error: `-prefixed message per §5, with an optional suggested fix.
func printError(_ message: String) {
    eprint("Error: \(message)\n")
}

/// A single-line, yellow warning - used for recoverable per-screen issues (e.g. a missing
/// screen that other screens in the same operation can still proceed without).
func printWarning(_ message: String) {
    let ce = colorEnabled(forceDisabled: stderrColorForceDisabled(), fd: fileno(stderr))
    let colored = colorize("Warning: \(message)", .yellow, enabled: ce)
    FileHandle.standardError.write((colored + "\n").data(using: .utf8)!)
}

/// Splits a string like `strtok_r` would with a set of single-character
/// delimiters: consecutive delimiters merge, leading/trailing delimiters are
/// dropped, and only these exact characters split (not general whitespace).
func tokenize(_ s: String, delimiters: Set<Character>) -> [String] {
    var tokens: [String] = []
    var current = ""
    for c in s {
        if delimiters.contains(c) {
            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        } else {
            current.append(c)
        }
    }
    if !current.isEmpty {
        tokens.append(current)
    }
    return tokens
}

/// C `atoi()`: skip leading whitespace, an optional sign, then digits: stop
/// at the first non-digit instead of requiring the whole string to be
/// numeric (unlike `Int(String)`). Returns 0 for nil/unparseable input.
func catoi(_ s: String?) -> Int {
    guard let s else { return 0 }
    var chars = Substring(s)
    while let first = chars.first, first == " " || first == "\t" || first == "\n" {
        chars.removeFirst()
    }

    var sign = 1
    if let first = chars.first, first == "+" || first == "-" {
        if first == "-" {
            sign = -1
        }
        chars.removeFirst()
    }

    var result = 0
    while let first = chars.first, first.isASCII, first.isNumber {
        result = result * 10 + Int(first.asciiValue! - 48)
        chars.removeFirst()
    }

    return sign * result
}
