// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "monctl",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "CDisplayCore",
            path: "Sources/CDisplayCore",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-Wno-deprecated-declarations", "-fno-objc-arc"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F/System/Library/PrivateFrameworks",
                    "-framework", "MonitorPanel",
                    "-framework", "SkyLight",
                    "-framework", "OSD",
                    "-framework", "CoreDisplay",
                    "-framework", "DisplayServices",
                ]),
            ]
        ),
        .executableTarget(
            name: "monctl",
            dependencies: [
                "CDisplayCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/monctl"
        ),
        .testTarget(
            name: "monctlTests",
            dependencies: ["monctl"],
            path: "Tests/Unit"
        ),
    ]
)
