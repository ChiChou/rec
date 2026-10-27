// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Rec",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "RecCore"),
        .executableTarget(
            name: "Rec",
            dependencies: ["RecCore"],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .testTarget(name: "RecCoreTests", dependencies: ["RecCore"]),
    ],
    swiftLanguageModes: [.v5]
)
