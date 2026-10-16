import AppKit
import CoreGraphics
import MerlinCore

/// Bir modülün olay için kararı.
enum ModuleResult {
    case pass
    case drop
}

/// Girdi zincirindeki bir halka (basma, kaydırma…). Ana iş parçacığında ve hızlı çalışmalı.
protocol InputModule: AnyObject {
    func handle(_ type: CGEventType, _ event: CGEvent) -> ModuleResult
}

/// Fare olay yakalayıcı: tapı kurar, olayı sırayla modüllere verir.
final class InputTap {
    static let shared = InputTap()

    /// Kendi ürettiğimiz olayları tanımak için işaret ("MRLN").
    static let syntheticTag: Int64 = 0x4D52_4C4E

    var onAction: ((String) -> Void)?

    var modules: [InputModule] = [PressModule(), ScrollModule()]

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    /// İznin gerçek (canlı) durumu: etkin bir deneme yakalayıcısı kurulabiliyor mu.
    /// `AXIsProcessTrusted` süreç içinde önbellekte kalır; izin geri alınsa da "var" demeye devam eder.
    /// Deneme yakalayıcısı olay akışını etkilemesin diye yalnız seyrek bir olay türünü ister ve hemen kaldırılır.
    static func canCreateActiveTap() -> Bool {
        let mask = CGEventMask(1) << CGEventType.tabletProximity.rawValue
        guard let probe = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: { _, _, event, _ in Unmanaged.passUnretained(event) }, userInfo: nil
        ) else { return false }
        CGEvent.tapEnable(tap: probe, enable: false)
        CFMachPortInvalidate(probe)
        return true
    }

    /// Yakalayıcıyı tamamen kaldırır. Erişilebilirlik izni giderken çalışan etkin bir yakalayıcı
    /// sistemin tüm fare olaylarını bekletir (fare ve ekran donar); izin düşer düşmez çağrılmalı.
    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
        // Orta tuşa çevrilmiş basma sürüyorsa hedef uygulamada tuş takılı kalmasın: işaretli bırakma gönder.
        if InputState.shared.middleDragActive,
           let up = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: .otherMouseUp,
                            mouseCursorPosition: CGEvent(source: nil)?.location ?? .zero, mouseButton: .center) {
            up.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            up.setIntegerValueField(.eventSourceUserData, value: Self.syntheticTag)
            up.post(tap: .cghidEventTap)
        }
        InputState.shared.middleDragActive = false
    }

    func start() -> Bool {
        if tap != nil { return true }
        // Durdurulmuş bir yakalayıcıdan yarım kalan basma oturumu taşınmasın.
        modules = [PressModule(), ScrollModule()]
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
            callback: { _, type, event, _ in InputTap.shared.handle(type, event) },
            userInfo: nil
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Kendiliğinden yeniden açılmaz: izin gerçekten varsa (canlı yoklama) yeniden açılır,
            // yoksa kaldırılır. `AXIsProcessTrusted` önbellekli olduğu için burada kullanılmaz.
            DispatchQueue.main.async {
                AppModel.shared.checkTrust(prompt: false)
                if let tap = InputTap.shared.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            }
            return pass
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticTag { return pass }
        guard Settings.shared.enabled, !AppModel.shared.isPaused else { return pass }
        for module in modules where module.handle(type, event) == .drop {
            return nil
        }
        return pass
    }
}
