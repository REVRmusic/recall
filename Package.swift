// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Recall",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Recall", targets: ["Recall"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Recall",
            dependencies: [],
            path: "Sources/Recall",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
