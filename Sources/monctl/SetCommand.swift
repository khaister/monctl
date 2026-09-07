import ApplicationServices
import ArgumentParser
import CDisplayCore
import Foundation

#if canImport(Glibc)
    import Glibc
#else
    import Darwin
#endif

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Apply configuration to a single screen"
    )

    @Option(help: "The screen to configure (persistent, contextual, or serial id).")
    var screen: String

    @Option(help: "Resolution as WIDTHxHEIGHT. Omitted hz/depth auto-pick the best available match.")
    var resolution: String?

    @Option(help: "Exact display mode number, from `list --long`.")
    var mode: Int?

    @Option(help: "Refresh rate in Hz.")
    var hz: Int?

    @Option(help: "Color depth.")
    var depth: Int?

    @Option(help: "Scaling: on or off.")
    var scaling: String?

    @Option(name: .customLong("right-of"), help: "Place this screen to the right of <id>'s current bounds.")
    var rightOf: String?

    @Option(name: .customLong("left-of"), help: "Place this screen to the left of <id>'s current bounds.")
    var leftOf: String?

    @Option(help: "Place this screen above <id>'s current bounds.")
    var above: String?

    @Option(help: "Place this screen below <id>'s current bounds.")
    var below: String?

    @Option(help: "Advanced: raw pixel origin as X,Y, for placements the relative flags can't express.")
    var origin: String?

    @Option(help: "Rotation in degrees: 0, 90, 180, or 270.")
    var rotate: Int?

    @Option(help: "Comma-separated ids of screens that should mirror this one.")
    var mirror: String?

    @Option(help: "Enable or disable this screen: true or false.")
    var enabled: Bool?

    @Flag(name: .customLong("dry-run"), help: "Print what would change, without applying.")
    var dryRun = false

    @Flag(help: "Don't error if <screen> isn't currently attached.")
    var quiet = false

    @OptionGroup var colorOptions: ColorOptions

    func validate() throws {
        let positioningFlags = [rightOf, leftOf, above, below, origin].compactMap(\.self)
        if positioningFlags.count > 1 {
            throw ValidationError(
                "only one of --right-of/--left-of/--above/--below/--origin may be given."
            )
        }
        if let scaling, scaling != "on", scaling != "off" {
            throw ValidationError("--scaling must be \"on\" or \"off\", got \"\(scaling)\".")
        }
        if let rotate, ![0, 90, 180, 270].contains(rotate) {
            throw ValidationError("--rotate must be 0, 90, 180, or 270, got \(rotate).")
        }
    }

    func run() throws {
        let onlineList = onlineDisplays()
        let id = convertUUIDtoID(screen)
        let ce = colorEnabled(forceDisabled: colorOptions.resolvedNoColor, fd: fileno(stdout))

        guard onlineList.contains(id) else {
            if quiet {
                return
            }
            printError("no screen matches id \"\(screen)\". Run 'monctl list' to see available ids.")
            throw ExitCode.failure
        }

        let current = currentScreenConfig(for: id)
        var target = current
        try applyOverrides(to: &target, currentID: id, onlineList: onlineList)
        target.quietMissingScreen = quiet

        // Resolve width/height/hz/depth/scaling (and any hz:0/depth:0 wildcard from
        // applyOverrides) down to one concrete mode up front, purely so the diff/dry-run
        // preview shows what "auto-pick the best match" actually means instead of a
        // misleading "hz: 120 -> 0". This lookup runs against modes for the screen's *current*
        // rotation, which may not be `target`'s rotation yet - so unless the user pinned an
        // exact mode with --mode, `target.modeNum` is reset to -1 afterward, and the real apply
        // (applyScreenConfigs, which rotates before resolving resolution) re-resolves
        // width/height/hz/depth/scaled against whatever the live mode table is by then, exactly
        // like combining a rotation and a resolution always has.
        if target.enabled {
            guard let resolvedMode = findMatchingMode(id, target) else {
                printNoMatchingModeError(screenUUID: current.uuid, config: target)
                throw ExitCode.failure
            }
            target.width = Int(resolvedMode.width)
            target.height = Int(resolvedMode.height)
            target.hz = Int(resolvedMode.freq)
            target.depth = Int(resolvedMode.depth)
            target.scaled = resolvedMode.density == 2.0
            target.modeNum = mode ?? -1
        }

        let diffs = diffScreenConfig(current: current, target: target)

        if dryRun {
            printDiff(diffs, colorEnabled: ce)
            return
        }

        guard applyScreenConfigs([target]) else {
            throw ExitCode.failure
        }

        printAppliedStatus(id: id)
    }

    /// Fills in every field the user actually passed a flag for, leaving everything else equal
    /// to `target`'s starting value (a copy of the screen's current state) - see `Diff.swift`'s
    /// doc comment for why that's what makes the later diff/apply correct.
    private func applyOverrides(
        to target: inout ScreenConfig,
        currentID: CGDirectDisplayID,
        onlineList: [CGDirectDisplayID]
    ) throws {
        if let resolution {
            let parts = tokenize(resolution, delimiters: ["x"])
            guard parts.count == 2 else {
                throw ValidationError("--resolution must be WIDTHxHEIGHT, e.g. 2560x1440.")
            }
            target.width = catoi(parts[0])
            target.height = catoi(parts[1])
            target.modeNum = -1
        }

        if let mode {
            let resolvedMode = getDisplayMode(currentID, Int32(mode))
            target.width = Int(resolvedMode.width)
            target.height = Int(resolvedMode.height)
            target.hz = Int(resolvedMode.freq)
            target.depth = Int(resolvedMode.depth)
            target.scaled = resolvedMode.density == 2.0
            target.modeNum = mode
        }

        // Unspecified hz/depth become wildcards (best-match) only when the resolution is
        // actually changing and --mode wasn't used to pin an exact mode - otherwise they stay
        // pinned to the screen's current values, matching auto-pick semantics.
        if let hz {
            target.hz = hz
        } else if resolution != nil {
            target.hz = 0
        }
        if let depth {
            target.depth = depth
        } else if resolution != nil {
            target.depth = 0
        }
        if let scaling {
            target.scaled = (scaling == "on")
        }

        if let origin {
            let parts = tokenize(origin, delimiters: [","])
            guard parts.count == 2 else {
                throw ValidationError("--origin must be X,Y, e.g. 1920,0.")
            }
            target.x = catoi(parts[0])
            target.y = catoi(parts[1])
        } else if let placement = relativePlacement() {
            guard let resolved = resolveRelativeOrigin(
                placement,
                onlineList: onlineList,
                targetWidth: target.width,
                targetHeight: target.height
            ) else {
                printError("no screen matches id \"\(placement.referenceID)\". Run 'monctl list' to see available ids.")
                throw ExitCode.failure
            }
            target.x = resolved.x
            target.y = resolved.y
        }

        if let rotate {
            target.degree = rotate
        }
        if let mirror {
            target.mirrorUUIDs = tokenize(mirror, delimiters: [","])
        }
        if let enabled {
            target.enabled = enabled
        }
    }

    private func relativePlacement() -> RelativePlacement? {
        if let rightOf {
            return .rightOf(rightOf)
        }
        if let leftOf {
            return .leftOf(leftOf)
        }
        if let above {
            return .above(above)
        }
        if let below {
            return .below(below)
        }
        return nil
    }

    private func printDiff(_ diffs: [FieldDiff], colorEnabled: Bool) {
        guard !diffs.isEmpty else {
            print("No changes.")
            return
        }
        print("Would apply:")
        for diff in diffs {
            print("  " + diff.rendered(colorEnabled: colorEnabled))
        }
    }

    private func printAppliedStatus(id: CGDirectDisplayID) {
        let final = gatherScreenInfo(id, includeModes: false)
        if !final.enabled {
            print("Applied: Screen \(final.contextualID) disabled")
            return
        }
        let hzText = final.hz != 0 ? "@\(final.hz)hz, " : ""
        print(
            "Applied: Screen \(final.contextualID) now \(final.width)x\(final.height) \(hzText)" +
                "origin (\(final.originX),\(final.originY)), rotated \(final.rotation)\u{B0}"
        )
    }
}
