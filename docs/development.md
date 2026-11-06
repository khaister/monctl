# Development

Install the tools (config lives in `.swiftformat` / `.swiftlint.yml`):

```sh
brew install swiftformat swiftlint
```

Check formatting (this is what CI runs):

```sh
swiftformat --lint .
```

Auto-fix formatting:

```sh
swiftformat .
```

Lint:

```sh
swiftlint lint
```

> [!NOTE]
> If you only have the Command Line Tools installed (no full Xcode.app) — check with `xcode-select -p` — plain `swiftlint lint` may crash with a `dlopen ... sourcekitdInProc.framework` error, since SwiftLint's search paths are Xcode.app-centric and don't include the CLT's copy of that framework. Point it there explicitly instead:
> ```sh
> DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib swiftlint lint
> ```
> If you have full Xcode.app installed, plain `swiftlint lint` works as-is.
