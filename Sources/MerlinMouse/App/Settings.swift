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
    /// Kenar kaydırma şeridinin genişliği (`EdgeSlideRecognizer.edgeWidthRange`).
    @Published var edgeWidth: Double { didSet { save(edgeWidth, "edgeWidth") } }
    /// Kenar kaydırmada bir adım için gereken dikey değişim (`EdgeSlideRecognizer.stepRange`).
    @Published var edgeStep: Double { didSet { save(edgeStep, "edgeStep") } }
    /// Ses ve parlaklık çeyrek adımlarla değişir (⇧⌥ + medya tuşu).
    @Published var edgeFineSteps: Bool { didSet { save(edgeFineSteps, "edgeFineSteps") } }
    /// Kenar kaydırma yönünü ters çevir (aşağı kaydırmak artırır).
    @Published var edgeInvert: Bool { didSet { save(edgeInvert, "edgeInvert") } }
    /// Kenar şeridinin alt ve üst ucu (y: 0 arka → 1 ön); iki kenar ortak. Yalnız `edgeBounds` ile yazılır.
    @Published private(set) var edgeBottom: Double { didSet { save(edgeBottom, "edgeBottom") } }
    @Published private(set) var edgeTop: Double { didSet { save(edgeTop, "edgeTop") } }

    /// Kenar şeridinin dikey aralığı; yazarken sıkıştırılır (0 ≤ alt, üst ≤ 0.85, yükseklik ≥ 0.15).
    var edgeBounds: EdgeStripBounds {
        get { EdgeStripBounds(bottom: edgeBottom, top: edgeTop) }
        set {
            let c = newValue.clamped()
            if c.bottom != edgeBottom { edgeBottom = c.bottom }
            if c.top != edgeTop { edgeTop = c.top }
        }
    }
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
    /// Ana pencerede düzenlenen aygıt (üst çubuktaki seçici); aygıta bağlı sayfalar bunu izler.
    @Published var editingDevice: InputDeviceKind { didSet { save(editingDevice.rawValue, "editingDevice") } }
    /// Trackpad köşelerinin ortak boyutu (Bölgeler › Trackpad); JSON olarak saklanır, yazarken sıkıştırılır.
    @Published var trackpadCorners: TrackpadCornerLayout {
        didSet {
            // didSet içindeki atama gözlemciyi yeniden çağırmaz; sıkıştırılmış değer burada yazılır.
            let c = trackpadCorners.clamped()
            if c != trackpadCorners { trackpadCorners = c }
            if let data = try? JSONEncoder().encode(c) { defaults.set(data, forKey: "trackpadCorners") }
        }
    }

    private init() {
        defaults.register(defaults: [
            "enabled": true, "zoneClick": true, "twoFingerClick": true, "threeFingerClick": true,
            "threeFingerTap": false, "fnDrag": true, "blockScrollWhileDragging": true, "calm3DScroll": true,
            "zoneWidth": 0.30, "flipY": false, "appearance": "system", "batteryAlertsEnabled": true,
            "language": "system", "onboardingCompleted": false,
            "pinchInvert": false, "pinchStep": PinchRecognizer.defaultStep,
            "edgeWidth": EdgeSlideRecognizer.defaultEdgeWidth, "edgeStep": EdgeSlideRecognizer.defaultStep,
            "edgeFineSteps": false, "edgeInvert": false,
            "edgeBottom": EdgeStripBounds.defaultBottom, "edgeTop": EdgeStripBounds.defaultTop,
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
        let widths = EdgeSlideRecognizer.edgeWidthRange
        edgeWidth = min(max(defaults.double(forKey: "edgeWidth"), widths.lowerBound), widths.upperBound)
        let steps = EdgeSlideRecognizer.stepRange
        edgeStep = min(max(defaults.double(forKey: "edgeStep"), steps.lowerBound), steps.upperBound)
        edgeFineSteps = defaults.bool(forKey: "edgeFineSteps")
        edgeInvert = defaults.bool(forKey: "edgeInvert")
        let bounds = EdgeStripBounds(bottom: defaults.double(forKey: "edgeBottom"),
                                     top: defaults.double(forKey: "edgeTop")).clamped()
        edgeBottom = bounds.bottom
        edgeTop = bounds.top
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
        editingDevice = defaults.string(forKey: "editingDevice").flatMap(InputDeviceKind.init(rawValue:)) ?? .magicMouse
        if let data = defaults.data(forKey: "trackpadCorners"),
           let saved = try? JSONDecoder().decode(TrackpadCornerLayout.self, from: data) {
            trackpadCorners = saved.clamped()
        } else {
            trackpadCorners = .standard
        }
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

    /// Fare haritasının geometrisini varsayılana döndürür: bölge düzeni, kenar şeridinin genişliği ve dikey aralığı.
    func resetZoneLayout() {
        zoneLayout = .standard
        edgeWidth = EdgeSlideRecognizer.defaultEdgeWidth
        edgeBounds = .standard
    }

    func applyAppearance() {
        switch appearance {
        case "light": NSApp?.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp?.appearance = NSAppearance(named: .darkAqua)
        default: NSApp?.appearance = nil
        }
    }
}
