// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypoWriter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "tw", targets: ["TypoWriter"]),
        .executable(name: "TypoWriterApp", targets: ["TypoWriterApp"]),
        .library(name: "TypoWriterCore", targets: ["Core"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.3.0")),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TypoWriter",
            dependencies: [
                "Core",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "TypoWriterApp",
            dependencies: ["Core"],
            exclude: ["Info.plist", "TypoWriterApp.entitlements"]
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
