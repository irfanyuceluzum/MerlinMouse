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
    /// Çimdikleme yönünü ters çevir (açma = uzaklaştır).
    @Published var pinchInvert: Bool { didSet { save(pinchInvert, "pinchInvert") } }
    /// Bir yakınlaştırma adımı için gereken mesafe değişimi (`PinchRecognizer.stepRange`).
    @Published var pinchStep: Double { didSet { save(pinchStep, "pinchStep") } }
    /// Bölge düzeni (sol/orta/sağ sınırları, ön/arka sınırı); JSON olarak saklanır.
    @Published var zoneLayout: ZoneLayout { didSet { saveLayout() } }
    /// Ön/arka yönü ters çevir (ayarlama için).
    @Published var flipY: Bool { didSet { save(flipY, "flipY") } }
    /// Düşük pil (%20, %10) bildirimleri.
    @Published var batteryAlertsEnabled: Bool { didSet { save(batteryAlertsEnabled, "batteryAlertsEnabled") } }
    /// İlk açılış rehberi tamamlandı ya da atlandı.
    @Published var onboardingCompleted: Bool { didSet { save(onboardingCompleted, "onboardingCompleted") } }
    /// "system", "light" veya "dark".
    @Published var appearance: String { didSet { save(appearance, "appearance"); applyAppearance() } }
    /// "system", "tr" veya "en"; "system" Mac'in dilini izler.
    @Published var language: String { didSet { save(language, "language"); Localization.apply() } }

    private init() {
        defaults.register(defaults: [
            "enabled": true, "zoneClick": true, "twoFingerClick": true, "threeFingerClick": true,
            "threeFingerTap": false, "fnDrag": true, "blockScrollWhileDragging": true, "calm3DScroll": true,
            "zoneWidth": 0.30, "flipY": false, "appearance": "system", "batteryAlertsEnabled": true,
            "language": "system", "onboardingCompleted": false,
            "pinchInvert": false, "pinchStep": PinchRecognizer.defaultStep,
        ])
        enabled = defaults.bool(forKey: "enabled")
        zoneClick = defaults.bool(forKey: "zoneClick")
        twoFingerClick = defaults.bool(forKey: "twoFingerClick")
        threeFingerClick = defaults.bool(forKey: "threeFingerClick")
        threeFingerTap = defaults.bool(forKey: "threeFingerTap")
        fnDrag = defaults.bool(forKey: "fnDrag")
        blockScrollWhileDragging = defaults.bool(forKey: "blockScrollWhileDragging")
        calm3DScroll = defaults.bool(forKey: "calm3DScroll")
        pinchInvert = defaults.bool(forKey: "pinchInvert")
        let range = PinchRecognizer.stepRange
        pinchStep = min(max(defaults.double(forKey: "pinchStep"), range.lowerBound), range.upperBound)
        // Eski "zoneWidth" yalnız göç kaynağı: düzen kayıtlı değilse ondan üretilir.
        if let data = defaults.data(forKey: "zoneLayout"),
           let saved = try? JSONDecoder().decode(ZoneLayout.self, from: data) {
            zoneLayout = saved.clamped()
        } else {
            zoneLayout = ZoneLayout.fromLegacy(zoneWidth: defaults.double(forKey: "zoneWidth"))
        }
        flipY = defaults.bool(forKey: "flipY")
        onboardingCompleted = defaults.bool(forKey: "onboardingCompleted")
        batteryAlertsEnabled = defaults.bool(forKey: "batteryAlertsEnabled")
        appearance = defaults.string(forKey: "appearance") ?? "system"
        language = defaults.string(forKey: "language") ?? "system"
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
