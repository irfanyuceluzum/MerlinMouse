import AppKit
import Combine

/// Kullanıcı ayarları; her değişiklik UserDefaults'a yazılır.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    @Published var enabled: Bool { didSet { save(enabled, "enabled") } }
    @Published var zoneClick: Bool { didSet { save(zoneClick, "zoneClick") } }
    @Published var twoFingerClick: Bool { didSet { save(twoFingerClick, "twoFingerClick") } }
    @Published var threeFingerClick: Bool { didSet { save(threeFingerClick, "threeFingerClick") } }
    @Published var threeFingerTap: Bool { didSet { save(threeFingerTap, "threeFingerTap") } }
    @Published var fnDrag: Bool { didSet { save(fnDrag, "fnDrag") } }
    @Published var blockScrollWhileDragging: Bool { didSet { save(blockScrollWhileDragging, "blockScrollWhileDragging") } }
    @Published var calm3DScroll: Bool { didSet { save(calm3DScroll, "calm3DScroll") } }
    /// Orta bölgenin genişliği, yüzey genişliğinin oranı olarak (0.15…0.45).
    @Published var zoneWidth: Double { didSet { save(zoneWidth, "zoneWidth") } }
    /// Ön/arka yönü ters çevir (ayarlama için).
    @Published var flipY: Bool { didSet { save(flipY, "flipY") } }
    /// "system", "light" veya "dark".
    @Published var appearance: String { didSet { save(appearance, "appearance"); applyAppearance() } }

    private init() {
        defaults.register(defaults: [
            "enabled": true, "zoneClick": true, "twoFingerClick": true, "threeFingerClick": true,
            "threeFingerTap": false, "fnDrag": true, "blockScrollWhileDragging": true, "calm3DScroll": true,
            "zoneWidth": 0.30, "flipY": false, "appearance": "system",
        ])
        enabled = defaults.bool(forKey: "enabled")
        zoneClick = defaults.bool(forKey: "zoneClick")
        twoFingerClick = defaults.bool(forKey: "twoFingerClick")
        threeFingerClick = defaults.bool(forKey: "threeFingerClick")
        threeFingerTap = defaults.bool(forKey: "threeFingerTap")
        fnDrag = defaults.bool(forKey: "fnDrag")
        blockScrollWhileDragging = defaults.bool(forKey: "blockScrollWhileDragging")
        calm3DScroll = defaults.bool(forKey: "calm3DScroll")
        zoneWidth = defaults.double(forKey: "zoneWidth")
        flipY = defaults.bool(forKey: "flipY")
        appearance = defaults.string(forKey: "appearance") ?? "system"
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }

    func applyAppearance() {
        switch appearance {
        case "light": NSApp?.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp?.appearance = NSAppearance(named: .darkAqua)
        default: NSApp?.appearance = nil
        }
    }
}
