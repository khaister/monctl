import ArgumentParser

struct Monctl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "monctl",
        discussion: helpDiscussion,
        version: versionText,
        subcommands: [List.self, SetCommand.self, Profile.self, Completion.self]
    )
}

struct Completion: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "completion",
        abstract: "Print a shell completion script"
    )

    @Argument(help: "One of: \(CompletionShell.allCases.map(\.rawValue).joined(separator: ", ")).")
    var shell: String

    func run() throws {
        guard let shell = CompletionShell(rawValue: shell) else {
            printError(
                "unsupported shell \"\(shell)\". Supported: " +
                    "\(CompletionShell.allCases.map(\.rawValue).joined(separator: ", "))."
            )
            throw ExitCode.failure
        }
        print(Monctl.completionScript(for: shell))
    }
}

Monctl.main()
