// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TokscaleMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TokscaleMac",
            path: "TokscaleMac"
        )
    ]
)
