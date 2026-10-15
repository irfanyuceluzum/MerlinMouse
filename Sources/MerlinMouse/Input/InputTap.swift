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
            callback: { _, type, event, _ in InputTap.shared.handle(type, event) },
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
        guard Settings.shared.enabled else { return pass }
        for module in modules where module.handle(type, event) == .drop {
            return nil
        }
        return pass
    }
}
