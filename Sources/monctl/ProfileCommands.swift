import ApplicationServices
import ArgumentParser
import Foundation

#if canImport(Glibc)
    import Glibc
#else
    import Darwin
#endif

struct Profile: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "profile",
        abstract: "Manage saved display layouts",
        subcommands: [
            ProfileSave.self,
            ProfileApply.self,
            ProfileList.self,
            ProfileShow.self,
            ProfileRm.self,
            ProfileEdit.self,
        ]
    )
}

struct ProfileSave: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "save",
        abstract: "Capture the current layout under a name"
    )

    @Argument(help: "Name to save this layout under.")
    var name: String

    func run() throws {
        let configs = groupedForProfile().map { primary, mirrors in
            currentScreenConfig(for: primary, mirrorUUIDs: mirrors.map { uuidString(for: $0) })
        }

        do {
            try ProfileStore.save(configs, name: name)
        } catch {
            printError("could not save profile \"\(name)\": \(error.localizedDescription)")
            throw ExitCode.failure
        }

        let screenWord = configs.count == 1 ? "screen" : "screens"
        print("Saved profile \"\(name)\" (\(configs.count) \(screenWord)) to \(ProfileStore.path(for: name).path)")
    }
}

struct ProfileApply: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apply",
        abstract: "Apply a saved layout, atomically, across all its screens"
    )

    @Argument(help: "Name of the saved layout to apply.")
    var name: String

    @Flag(name: .customLong("dry-run"), help: "Print the diff, don't apply, don't prompt.")
    var dryRun = false

    @OptionGroup var colorOptions: ColorOptions

    func run() throws {
        guard ProfileStore.exists(name: name) else {
            printError("no profile named \"\(name)\". Run 'monctl profile list' to see saved profiles.")
            throw ExitCode.failure
        }

        let configs: [ScreenConfig]
        do {
            configs = try ProfileStore.load(name: name)
        } catch {
            printError("could not read profile \"\(name)\": \(error.localizedDescription)")
            throw ExitCode.failure
        }

        let onlineList = onlineDisplays()
        let stdoutColor = colorEnabled(noColor: colorOptions.noColor, fd: fileno(stdout))
        let diffLines = configs.enumerated().map { index, target -> String in
            let prefix = "Screen \(index + 1)"
            let id = convertUUIDtoID(target.uuid)
            guard onlineList.contains(id) else {
                return "\(prefix): screen not found - skipping"
            }
            let current = currentScreenConfig(for: id)
            return renderDiffLine(
                prefix: prefix,
                diffs: diffScreenConfig(current: current, target: target),
                colorEnabled: stdoutColor
            )
        }

        if dryRun {
            print("Would apply profile \"\(name)\":")
            diffLines.forEach { print("  " + $0) }
            return
        }

        print("Apply profile \"\(name)\":")
        diffLines.forEach { print("  " + $0) }

        if ProcessInfo.processInfo.environment["MONCTL_PROFILE_APPLY_NO_CONFIRM"] != "1" {
            let stderrColor = colorEnabled(noColor: colorOptions.noColor, fd: fileno(stderr))
            FileHandle.standardError.write(Data(colorize("Apply this? [y/N] ", .yellow, enabled: stderrColor).utf8))
            let answer = readLine()?.lowercased() ?? ""
            guard answer == "y" || answer == "yes" else {
                eprint("Cancelled.\n")
                return
            }
        }

        guard applyScreenConfigs(configs) else {
            throw ExitCode.failure
        }
        print("Applied profile \"\(name)\"")
    }
}

struct ProfileList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List saved profiles")

    @Flag(help: "Output machine-readable JSON.")
    var json = false

    private struct Entry: Encodable {
        let name: String
        let screens: Int
    }

    func run() throws {
        let names = ProfileStore.list()
        let entries = names.map { Entry(name: $0, screens: (try? ProfileStore.load(name: $0).count) ?? 0) }

        if json {
            try printJSON(entries)
            return
        }

        guard !entries.isEmpty else {
            print("No saved profiles.")
            return
        }
        for entry in entries {
            print("\(entry.name) (\(entry.screens) screen\(entry.screens == 1 ? "" : "s"))")
        }
    }
}

struct ProfileShow: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "Print a saved profile")

    @Argument(help: "Name of the saved layout to show.")
    var name: String

    @Flag(help: "Output machine-readable JSON.")
    var json = false

    func run() throws {
        guard ProfileStore.exists(name: name) else {
            printError("no profile named \"\(name)\". Run 'monctl profile list' to see saved profiles.")
            throw ExitCode.failure
        }

        let configs: [ScreenConfig]
        do {
            configs = try ProfileStore.load(name: name)
        } catch {
            printError("could not read profile \"\(name)\": \(error.localizedDescription)")
            throw ExitCode.failure
        }

        if json {
            try printJSON(configs)
            return
        }

        for (index, config) in configs.enumerated() {
            print("Screen \(index + 1): \(config.uuid)")
            print(
                "  Resolution: \(config.width)x\(config.height)  Hz: \(config.hz)  " +
                    "Depth: \(config.depth)  Scaling: \(config.scaled ? "on" : "off")"
            )
            print("  Origin: (\(config.x),\(config.y))  Rotation: \(config.degree)  Enabled: \(config.enabled)")
            if !config.mirrorUUIDs.isEmpty {
                print("  Mirrors: \(config.mirrorUUIDs.joined(separator: ", "))")
            }
        }
    }
}

struct ProfileRm: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rm", abstract: "Remove a saved profile")

    @Argument(help: "Name of the saved layout to remove.")
    var name: String

    func run() throws {
        guard ProfileStore.exists(name: name) else {
            printError("no profile named \"\(name)\". Run 'monctl profile list' to see saved profiles.")
            throw ExitCode.failure
        }
        do {
            try ProfileStore.remove(name: name)
        } catch {
            printError("could not remove profile \"\(name)\": \(error.localizedDescription)")
            throw ExitCode.failure
        }
        print("Removed profile \"\(name)\"")
    }
}

struct ProfileEdit: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "edit", abstract: "Open a saved profile in $EDITOR")

    @Argument(help: "Name of the saved layout to edit.")
    var name: String

    func run() throws {
        guard ProfileStore.exists(name: name) else {
            printError("no profile named \"\(name)\". Run 'monctl profile list' to see saved profiles.")
            throw ExitCode.failure
        }

        let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "vi"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [editor, ProfileStore.path(for: name).path]

        do {
            try process.run()
        } catch {
            printError("could not launch \"\(editor)\": \(error.localizedDescription)")
            throw ExitCode.failure
        }
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ExitCode(process.terminationStatus)
        }
    }
}
