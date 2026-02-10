// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mactokio",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Mactokio",
            targets: ["Mactokio"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Mactokio",
            path: "Sources",
            resources: [
                .process("../Assets.xcassets")
            ]
        )
    ]
)
