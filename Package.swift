// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SpaceRenamer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpaceRenamer", targets: ["SpaceRenamer"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SpaceRenamer",
            dependencies: [],
            path: "Sources/SpaceRenamer"
        )
    ]
)
