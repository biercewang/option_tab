// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrustedAltTab",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TrustedAltTab", targets: ["TrustedAltTab"])
    ],
    targets: [
        .executableTarget(
            name: "TrustedAltTab",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics")
            ]
        )
    ]
)
