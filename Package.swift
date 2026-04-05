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
        .target(
            name: "CGSPrivate",
            path: "Sources/CGSPrivate",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "SpaceRenamer",
            dependencies: ["CGSPrivate"],
            path: "Sources/SpaceRenamer"
        )
    ]
)
