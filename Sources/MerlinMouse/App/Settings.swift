import AppKit
import Combine
import MerlinCore

/// Kullanıcı ayarları; her değişiklik UserDefaults'a yazılır.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    @Published var enabled: Bool { didSet { save(enabled, "enabled") } }
    // Eski, yalnız göç: atamalar artık bindings.json'da; bu bayraklar yazılmaz, yalnız ilk göçte okunur.
    private(set) var zoneClick: Bool
    private(set) var twoFingerClick: Bool
    private(set) var threeFingerClick: Bool
    private(set) var threeFingerTap: Bool
    private(set) var fnDrag: Bool
    /// Duraklatma bitiş zamanı (geçmişse nil).
    @Published var pausedUntil: Date? { didSet { defaults.set(pausedUntil, forKey: "pausedUntil") } }
    @Published var blockScrollWhileDragging: Bool { didSet { save(blockScrollWhileDragging, "blockScrollWhileDragging") } }
    @Published var calm3DScroll: Bool { didSet { save(calm3DScroll, "calm3DScroll") } }
    /// Bölge düzeni (sol/orta/sağ sınırları, ön/arka sınırı); JSON olarak saklanır.
    @Published var zoneLayout: ZoneLayout { didSet { saveLayout() } }
    /// Ön/arka yönü ters çevir (ayarlama için).
    @Published var flipY: Bool { didSet { save(flipY, "flipY") } }
    /// Düşük pil (%20, %10) bildirimleri.
    @Published var batteryAlertsEnabled: Bool { didSet { save(batteryAlertsEnabled, "batteryAlertsEnabled") } }
    /// "system", "light" veya "dark".
    @Published var appearance: String { didSet { save(appearance, "appearance"); applyAppearance() } }

    private init() {
        defaults.register(defaults: [
            "enabled": true, "zoneClick": true, "twoFingerClick": true, "threeFingerClick": true,
            "threeFingerTap": false, "fnDrag": true, "blockScrollWhileDragging": true, "calm3DScroll": true,
            "zoneWidth": 0.30, "flipY": false, "appearance": "system", "batteryAlertsEnabled": true,
        ])
        enabled = defaults.bool(forKey: "enabled")
        zoneClick = defaults.bool(forKey: "zoneClick")
        twoFingerClick = defaults.bool(forKey: "twoFingerClick")
        threeFingerClick = defaults.bool(forKey: "threeFingerClick")
        threeFingerTap = defaults.bool(forKey: "threeFingerTap")
        fnDrag = defaults.bool(forKey: "fnDrag")
        blockScrollWhileDragging = defaults.bool(forKey: "blockScrollWhileDragging")
        calm3DScroll = defaults.bool(forKey: "calm3DScroll")
        // Eski "zoneWidth" yalnız göç kaynağı: düzen kayıtlı değilse ondan üretilir.
        if let data = defaults.data(forKey: "zoneLayout"),
           let saved = try? JSONDecoder().decode(ZoneLayout.self, from: data) {
            zoneLayout = saved.clamped()
        } else {
            zoneLayout = ZoneLayout.fromLegacy(zoneWidth: defaults.double(forKey: "zoneWidth"))
        }
        flipY = defaults.bool(forKey: "flipY")
        batteryAlertsEnabled = defaults.bool(forKey: "batteryAlertsEnabled")
        appearance = defaults.string(forKey: "appearance") ?? "system"
        if let until = defaults.object(forKey: "pausedUntil") as? Date, until > Date() {
            pausedUntil = until
        } else {
            pausedUntil = nil
        }
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }

    private func saveLayout() {
        if let data = try? JSONEncoder().encode(zoneLayout) { defaults.set(data, forKey: "zoneLayout") }
    }

    func resetZoneLayout() { zoneLayout = .standard }

    func applyAppearance() {
        switch appearance {
        case "light": NSApp?.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp?.appearance = NSAppearance(named: .darkAqua)
        default: NSApp?.appearance = nil
        }
    }
}
