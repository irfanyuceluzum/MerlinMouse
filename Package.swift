// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MerlinMouse",
    platforms: [.macOS("15.0")],
    targets: [
        // Özel MultitouchSupport framework'üne dlopen ile bağlanan küçük C köprüsü.
        .target(name: "CMultitouch", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]),
        // Saf model ve mantık (yalnız Foundation): tetik, eylem, atama, çakışma denetçisi.
        .target(name: "MerlinCore"),
        .executableTarget(name: "MerlinMouse", dependencies: ["CMultitouch", "MerlinCore"]),
        .testTarget(name: "MerlinCoreTests", dependencies: ["MerlinCore"]),
    ]
)
