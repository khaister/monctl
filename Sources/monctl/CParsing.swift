import Foundation

func eprint(_ s: String) {
    FileHandle.standardError.write(s.data(using: .utf8)!)
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

/// Splits `s` into the part before the first occurrence of `delimiter` and
/// the part after it (nil if `delimiter` doesn't appear) - matching a single
/// `strtok_r(s, ":", &savePtr)` call followed by one more.
func splitFirst(_ s: String, on delimiter: Character) -> (String, String?) {
    if let idx = s.firstIndex(of: delimiter) {
        return (String(s[s.startIndex..<idx]), String(s[s.index(after: idx)...]))
    }
    return (s, nil)
}

/// C `atoi()`: skip leading whitespace, an optional sign, then digits: stop
/// at the first non-digit instead of requiring the whole string to be
/// numeric (unlike `Int(String)`). Returns 0 for nil/unparseable input.
func catoi(_ s: String?) -> Int {
    guard let s = s else { return 0 }
    var chars = Substring(s)
    while let first = chars.first, first == " " || first == "\t" || first == "\n" {
        chars.removeFirst()
    }

    var sign = 1
    if let first = chars.first, first == "+" || first == "-" {
        if first == "-" { sign = -1 }
        chars.removeFirst()
    }

    var result = 0
    while let first = chars.first, first.isASCII, first.isNumber {
        result = result * 10 + Int(first.asciiValue! - 48)
        chars.removeFirst()
    }

    return sign * result
}
