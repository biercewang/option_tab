// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AltGesture",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AltGesture", targets: ["AltGesture"])
    ],
    targets: [
        .executableTarget(
            name: "AltGesture",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics")
            ]
        )
    ]
)
