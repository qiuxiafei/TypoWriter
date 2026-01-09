// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BetterVoiceInput",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "bvi", targets: ["BetterVoiceInput"]),
        .library(name: "BetterVoiceInputCore", targets: ["Core"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.3.0")),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "BetterVoiceInput",
            dependencies: [
                "Core",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "Core",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        )
    ]
)
