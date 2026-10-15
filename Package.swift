// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MerlinMouse",
    platforms: [.macOS(.v14)],
    targets: [
        // Özel MultitouchSupport framework'üne dlopen ile bağlanan küçük C köprüsü.
        .target(name: "CMultitouch"),
        .executableTarget(name: "MerlinMouse", dependencies: ["CMultitouch"]),
    ]
)
