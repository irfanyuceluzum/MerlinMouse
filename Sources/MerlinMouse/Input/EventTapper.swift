import AppKit
import CoreGraphics

/// Sol/sağ tıklamaları yakalar; kurala uyanları orta tuşa (button 2) çevirir.
/// Basılı tutulursa sürükleme olayları da orta tuş sürüklemesi olarak gider.
final class EventTapper {
    static let shared = EventTapper()

    /// Kendi ürettiğimiz olayları tanımak için işaret ("MRLN").
    static let syntheticTag: Int64 = 0x4D52_4C4E

    var onAction: ((String) -> Void)?

    private var tap: CFMachPort?
    /// Şu an orta tuşa çevrilen fiziksel tuş (sol ya da sağ).
    private var converting: CGMouseButton?
    private var reason = ""
    private var dragged = false

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .scrollWheel,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, _ in EventTapper.shared.handle(type, event) },
            userInfo: nil
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticTag { return pass }
        let settings = Settings.shared
        guard settings.enabled else { return pass }

        switch type {
        case .leftMouseDown, .rightMouseDown:
            TouchMonitor.shared.noteClick()
            guard converting == nil, let why = conversionReason(type, event, settings) else { return pass }
            converting = type == .leftMouseDown ? .left : .right
            reason = why
            dragged = false
            makeMiddle(event, .otherMouseDown)

        case .leftMouseDragged, .rightMouseDragged:
            guard isConverted(type) else { return pass }
            if !dragged {
                dragged = true
                report("Orta tuş sürükleme · \(reason)")
            }
            makeMiddle(event, .otherMouseDragged)

        case .leftMouseUp, .rightMouseUp:
            guard isConverted(type) else { return pass }
            makeMiddle(event, .otherMouseUp)
            if !dragged { report("Orta tıklama · \(reason)") }
            converting = nil

        case .scrollWheel:
            // Orta tuşla sürüklerken yüzeye değen parmak modeli yakınlaştırmasın.
            if converting != nil && settings.blockScrollWhileDragging { return nil }
            // 3D programlarda ataletli (momentum) kaydırmayı at: yakınlaştırma adım adım olsun.
            if settings.calm3DScroll && FrontApp.shared.is3D
                && event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 {
                return nil
            }

        default:
            break
        }
        return pass
    }

    private func conversionReason(_ type: CGEventType, _ event: CGEvent, _ s: Settings) -> String? {
        if s.fnDrag && type == .leftMouseDown && event.flags.contains(.maskSecondaryFn) { return "Fn" }
        // Avuç içini saymamak için yalnızca öndeki parmaklara bak.
        let fingers = TouchMonitor.shared.touches.filter { $0.front(flipped: s.flipY) >= TouchMonitor.frontLimit }
        switch fingers.count {
        case 3...:
            return s.threeFingerClick ? "üç parmak" : nil
        case 2:
            return s.twoFingerClick ? "iki parmak" : nil
        case 1:
            guard s.zoneClick, abs(Double(fingers[0].x) - 0.5) <= s.zoneWidth / 2 else { return nil }
            return "orta bölge"
        default:
            return nil
        }
    }

    private func isConverted(_ type: CGEventType) -> Bool {
        switch type {
        case .leftMouseDragged, .leftMouseUp: return converting == .left
        case .rightMouseDragged, .rightMouseUp: return converting == .right
        default: return false
        }
    }

    private func makeMiddle(_ event: CGEvent, _ type: CGEventType) {
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
    }

    private func report(_ text: String) {
        DispatchQueue.main.async { self.onAction?(text) }
    }

    /// İmlecin olduğu yere orta tıklama gönderir (üç parmakla dokunma için).
    func postMiddleClick() {
        let location = CGEvent(source: nil)?.location ?? .zero
        let source = CGEventSource(stateID: .hidSystemState)
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                      mouseCursorPosition: location, mouseButton: .center) else { continue }
            event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticTag)
            event.post(tap: .cghidEventTap)
        }
    }
}

/// Öndeki uygulamayı izler; 3D / dilimleyici programları tanır.
final class FrontApp: ObservableObject {
    static let shared = FrontApp()

    private static let keywords = [
        "chitubox", "lychee", "blender", "bambu", "prusa", "orca", "cura", "fusion",
        "freecad", "rhino", "sketchup", "cinema 4d", "maya", "zbrush", "meshmixer", "shapr3d",
    ]

    @Published private(set) var name = ""
    @Published private(set) var is3D = false

    private init() {
        update(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.update(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
    }

    private func update(_ app: NSRunningApplication?) {
        name = app?.localizedName ?? ""
        let haystack = "\(app?.bundleIdentifier ?? "") \(name)".lowercased()
        is3D = Self.keywords.contains { haystack.contains($0) }
    }
}
