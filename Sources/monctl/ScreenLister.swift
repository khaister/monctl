import ApplicationServices
import ArgumentParser
import CDisplayCore
import Foundation

#if canImport(Glibc)
    import Glibc
#else
    import Darwin
#endif

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show connected screens and their current configuration"
    )

    @Flag(help: "Show full per-screen detail: alternate ids, exact depth, and the full mode list.")
    var long = false

    @Option(help: "Scope --long output to a single screen (persistent, contextual, or serial id).")
    var screen: String?

    @Option(help: "Scope --long's mode list to a single resolution, as WIDTHxHEIGHT.")
    var resolution: String?

    @Flag(help: "Output machine-readable JSON. Always full detail, regardless of --long.")
    var json = false

    @OptionGroup var colorOptions: ColorOptions

    func run() throws {
        let screenIDs = onlineDisplays()

        if json {
            let infos = screenIDs.map { gatherScreenInfo($0, includeModes: true) }
            print(renderScreenInfosJSON(infos))
            return
        }

        if long {
            try runLong(screenIDs)
            return
        }

        printCompact(screenIDs)
    }

    private func parsedResolutionFilter() throws -> (width: Int, height: Int)? {
        guard let resolution else { return nil }
        let parts = tokenize(resolution, delimiters: ["x"])
        guard parts.count == 2 else {
            throw ValidationError("--resolution must be WIDTHxHEIGHT, e.g. 2560x1440.")
        }
        return (catoi(parts[0]), catoi(parts[1]))
    }

    private func printCompact(_ screenIDs: [CGDirectDisplayID]) {
        let ce = colorEnabled(forceDisabled: colorOptions.resolvedNoColor, fd: fileno(stdout))
        let infos = screenIDs.map { gatherScreenInfo($0, includeModes: false) }

        let headers = ["ID", "MAIN", "TYPE", "RESOLUTION", "HZ", "SCALING", "ORIGIN", "ROTATE", "ENABLED"]
        let rows = infos.map { info in
            [
                info.persistentID,
                info.isMain ? "*" : "",
                info.typeDescription,
                "\(info.width)x\(info.height)",
                info.hz != 0 ? "\(info.hz)" : "N/A",
                info.scaling ? "on" : "off",
                "(\(info.originX),\(info.originY))",
                "\(info.rotation)",
                "\(info.enabled)",
            ]
        }

        printTable(headers: headers, rows: rows, colorColumn: 0, colorEnabled: ce)
    }

    private func runLong(_ screenIDs: [CGDirectDisplayID]) throws {
        var infos = screenIDs.map { gatherScreenInfo($0, includeModes: true) }

        if let screen {
            let wantedID = convertUUIDtoID(screen)
            infos = infos.filter { $0.contextualID == wantedID }
            guard !infos.isEmpty else {
                printError("no screen matches id \"\(screen)\". Run 'monctl list' to see available ids.")
                throw ExitCode.failure
            }
        }

        let resolutionFilter = try parsedResolutionFilter()
        let settings = Settings.current
        let blocks = infos.map { renderLongBlock($0, fields: settings.longFields, resolutionFilter: resolutionFilter) }
        pageOutput(blocks.joined(separator: "\n\n"), pager: settings.pager, disablePager: settings.disablePager)
    }
}

private struct ModeGroup {
    let width: Int
    let height: Int
    var entries: [ScreenModeInfo]
}

private func groupModes(_ modes: [ScreenModeInfo]) -> [ModeGroup] {
    var groups: [String: ModeGroup] = [:]
    var order: [String] = []
    for mode in modes {
        let key = "\(mode.width)x\(mode.height)"
        if groups[key] == nil {
            groups[key] = ModeGroup(width: mode.width, height: mode.height, entries: [])
            order.append(key)
        }
        groups[key]?.entries.append(mode)
    }
    return order.compactMap { groups[$0] }.sorted { $0.width * $0.height > $1.width * $1.height }
}

private func renderLongBlock(
    _ info: ScreenInfo,
    fields: [LongFieldConfig],
    resolutionFilter: (width: Int, height: Int)?
) -> String {
    var lines: [String] = []
    lines.append("Screen \(info.persistentID)\(info.isMain ? " (main)" : "")")

    let pairs = fields.map { field in (label: field.resolvedLabel(), value: field.key.value(for: info)) }
    lines.append(contentsOf: renderMenuLines(pairs, indent: "  "))

    lines.append("  Modes:")

    var groups = groupModes(info.modes)
    if let resolutionFilter {
        groups = groups.filter { $0.width == resolutionFilter.width && $0.height == resolutionFilter.height }
    }

    for group in groups {
        lines.append("    \(group.width)x\(group.height)")
        let entries = group.entries.sorted { $0.hz != $1.hz ? $0.hz > $1.hz : $0.depth > $1.depth }
        for entry in entries {
            var line = "      hz:\(entry.hz) depth:\(entry.depth)"
            if entry.scaling {
                line += " scaling:on"
            }
            if entry.isCurrent {
                line += " <-- current mode"
            }
            lines.append(line)
        }
    }

    return lines.joined(separator: "\n")
}

/// Renders `label`/`value` pairs as dot-leader "menu" lines - `Label ..... value` - with labels
/// left-aligned and values right-aligned to the same column, like a restaurant menu. The dot
/// run for each line absorbs however much both its label and its value fall short of the
/// widest label/value in `pairs`, plus a fixed minimum, so the left edge of every label and the
/// right edge of every value land in the same column across the whole block - even when one
/// value (e.g. `persistentId`'s 36-character UUID) is much longer than the rest, which just
/// means every dot run stretches out to match it.
private func renderMenuLines(_ pairs: [(label: String, value: String)], indent: String) -> [String] {
    guard !pairs.isEmpty else { return [] }
    let minDots = 3
    let labelWidth = pairs.map(\.label.count).max() ?? 0
    let valueWidth = pairs.map(\.value.count).max() ?? 0

    return pairs.map { pair in
        let dotCount = (labelWidth - pair.label.count) + (valueWidth - pair.value.count) + minDots
        let dots = String(repeating: ".", count: dotCount)
        return "\(indent)\(pair.label) \(dots) \(pair.value)"
    }
}

/// Left-aligns `rows` (with `headers` as the first row) into columns sized to the widest plain
/// (uncolored) cell, per Heroku's grep/awk-parseable column convention (§2). `colorColumn`, if
/// given, is colorized after padding so escape codes never affect alignment.
func printTable(headers: [String], rows: [[String]], colorColumn: Int?, colorEnabled: Bool) {
    var widths = headers.map(\.count)
    for row in rows {
        for (i, cell) in row.enumerated() {
            widths[i] = max(widths[i], cell.count)
        }
    }

    func render(_ cells: [String]) -> String {
        cells.enumerated().map { i, cell in
            let isLast = i == cells.count - 1
            let padded = isLast ? cell : cell + String(repeating: " ", count: widths[i] - cell.count)
            return i == colorColumn ? colorize(padded, .cyan, enabled: colorEnabled) : padded
        }.joined(separator: "  ")
    }

    print(render(headers))
    for row in rows {
        print(render(row))
    }
}

/// Pipes `text` through `pager` (a `Settings.current.pager`, already resolved from `$PAGER`/the
/// config file/the "less" default) when stdout is a TTY, per §5; otherwise prints it directly,
/// since a script or redirect should get plain text, not a pager invocation that hangs waiting
/// for a terminal. `disablePager` skips paging unconditionally, for people who always want
/// plain output.
func pageOutput(_ text: String, pager: String, disablePager: Bool) {
    guard !disablePager, isatty(fileno(stdout)) != 0 else {
        print(text)
        return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", pager] // -c (not env) so a pager command like "less -R" still works
    let inputPipe = Pipe()
    process.standardInput = inputPipe

    guard (try? process.run()) != nil else {
        print(text)
        return
    }

    // Foundation spawns the pager into its own new process group, but never grants it control
    // of the terminal - so the instant an interactive pager like `less` tries to configure the
    // tty (to read keystrokes, enter raw mode), the kernel stops it with SIGTTOU/SIGTTIN, and it
    // hangs invisibly (state "T", not spinning) instead of paging. A shell avoids this for
    // foreground jobs by handing the tty to the child's process group first, then reclaiming it
    // after - do the same thing here.
    let ttyFd = STDIN_FILENO
    let ownPgrp = getpgrp()
    let pagerPgrp = process.processIdentifier
    tcsetpgrp(ttyFd, pagerPgrp)
    defer {
        // Reclaiming the tty happens while we're momentarily a background process ourselves, so
        // ignore SIGTTOU around the call or the kernel would stop *us* the same way.
        signal(SIGTTOU, SIG_IGN)
        tcsetpgrp(ttyFd, ownPgrp)
        signal(SIGTTOU, SIG_DFL)
    }

    inputPipe.fileHandleForWriting.write(Data(text.utf8))
    try? inputPipe.fileHandleForWriting.close()
    process.waitUntilExit()
}
