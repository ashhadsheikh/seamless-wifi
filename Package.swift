// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SeamlessWiFi",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SeamlessWiFi", targets: ["SeamlessWiFi"]),
        .executable(name: "seamless-wifi-probe", targets: ["SeamlessWiFiProbe"])
    ],
    targets: [
        .target(name: "WiFiCore", path: "Sources/WiFiCore"),
        .executableTarget(name: "SeamlessWiFi", dependencies: ["WiFiCore"], path: "Sources/SeamlessWiFi"),
        .executableTarget(name: "SeamlessWiFiProbe", path: "Sources/SeamlessWiFiProbe"),
        .testTarget(name: "SeamlessWiFiTests", dependencies: ["WiFiCore"], path: "Tests/SeamlessWiFiTests")
    ]
)
