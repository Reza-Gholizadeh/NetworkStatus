// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NetStatusWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NetStatusWidget",
            path: "Sources/NetStatusWidget"
        )
    ]
)
