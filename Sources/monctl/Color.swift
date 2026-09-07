import ArgumentParser
import Foundation

#if canImport(Glibc)
    import Glibc
#else
    import Darwin
#endif

/// Shared `--no-color` flag, embedded via `@OptionGroup` in any command that produces colored
/// output (`list`, `set`, `profile apply`, `profile show`).
struct ColorOptions: ParsableArguments {
    @Flag(name: .customLong("no-color"), help: "Disable colored output.")
    var noColor = false
}

enum SGR: Int {
    case red = 31
    case green = 32
    case yellow = 33
    case cyan = 36
    case dim = 2
}

/// True when color should be used for `fd` (stdout or stderr): not suppressed by `--no-color`
/// or `NO_COLOR`, and the stream is actually a TTY (never color when piped/redirected).
func colorEnabled(noColor: Bool, fd: Int32) -> Bool {
    if noColor {
        return false
    }
    if ProcessInfo.processInfo.environment["NO_COLOR"] != nil {
        return false
    }
    return isatty(fd) != 0
}

func colorize(_ text: String, _ codes: SGR..., enabled: Bool) -> String {
    guard enabled, !codes.isEmpty else { return text }
    let prefix = codes.map { String($0.rawValue) }.joined(separator: ";")
    return "\u{1B}[\(prefix)m\(text)\u{1B}[0m"
}
