import AppKit
import CoreGraphics
import MerlinCore

/// Tüm `GestureAction` türlerini yürütür. Ana kuyruktan çağrılır; her sentetik olay işaretlenir.
enum ActionExecutor {
    static func run(_ action: GestureAction) {
        switch action {
        case .middleClick, .back, .forward:
            if let n = action.buttonNumber { postButton(n) }
        case .middleDrag(let modifiers):
            // Basmasız tetiklerde düzenleyicili tek orta tıklama.
            postButton(2, flags: flags(forModifiers: modifiers))
        case .zoom(let style, let modifiers):
            zoomStep(direction: 1, style: style, modifiers: modifiers)
        case .shortcut(let combo):
            postKey(combo)
        case .system(let system):
            postKey(system.keyCombo)
        case .openApp(let path, let name):
            openApp(path: path, name: name)
        case .runShortcut(let name):
            runShortcut(name)
        }
    }

    /// Bir yakınlaştırma adımı: +1 yakınlaştır, −1 uzaklaştır (`pinchInvert` açıksa ters).
    /// `wheel`: tek satırlık tekerlek olayı (düzenleyiciler bayraklara, örn. ⌃ + tekerlek);
    /// `keys`: ⌘+ / ⌘− (sayısal tuş takımı); `gesture`: tek seferlik başladı / değişti / bitti büyütme hareketi.
    static func zoomStep(direction: Int, style: ZoomStyle, modifiers: [String] = []) {
        guard direction != 0 else { return }
        let zoomIn = (Settings.shared.pinchInvert ? -direction : direction) > 0
        switch style {
        case .wheel:
            let mods = GestureAction.zoomModifiers(modifiers, style: .wheel)
            let source = CGEventSource(stateID: .hidSystemState)
            guard let event = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1,
                                      wheel1: zoomIn ? 1 : -1, wheel2: 0, wheel3: 0) else { return }
            if !mods.isEmpty { event.flags = event.flags.union(flags(forModifiers: mods)) }
            event.setIntegerValueField(.eventSourceUserData, value: InputTap.syntheticTag)
            event.post(tap: .cghidEventTap)
        case .keys:
            // Sayısal tuş takımının + (69) / − (78) tuşları her klavye düzeninde aynı karakteri verir;
            // ana satırdaki = / - tuşlarının yeri düzene göre değişir (Türkçe Q'da 27 "*" yazar).
            postKey(KeyCombo(keyCode: zoomIn ? 69 : 78, modifiers: ["command"], display: zoomIn ? "⌘+" : "⌘−"))
        case .gesture:
            magnify(phase: Magnify.phaseBegan, amount: 0)
            magnify(phase: Magnify.phaseChanged, amount: zoomIn ? 0.1 : -0.1)
            magnify(phase: Magnify.phaseEnded, amount: 0)
        }
    }

    /// Trackpad büyütme hareketinin gizli (belgelenmemiş) CGEvent alanları; Mac Mouse Fix'in kullandığı değerler.
    enum Magnify {
        /// NSEventTypeGesture: trackpad hareketlerinin ortak olay türü.
        static let eventType: UInt32 = 29
        /// Alan 110: hareketin IOHIDEventType alt türü.
        static let subtypeField: UInt32 = 110
        /// kIOHIDEventTypeZoom: büyütme (çimdikleme) hareketi.
        static let subtypeZoom: Int64 = 8
        /// Alan 113: bu olaydaki göreli büyütme miktarı (double; NSEvent.magnification).
        static let amountField: UInt32 = 113
        /// Alan 132: IOHIDEventPhase evresi.
        static let phaseField: UInt32 = 132
        static let phaseBegan: Int64 = 1
        static let phaseChanged: Int64 = 2
        static let phaseEnded: Int64 = 4
        static let phaseCancelled: Int64 = 8
    }

    /// Tek bir trackpad büyütme olayı gönderir. Sıra: başlangıçta bir kez `phaseBegan` (miktar 0),
    /// hareket boyunca `phaseChanged` (miktarlar), sonda `phaseEnded` (miktar 0).
    static func magnify(phase: Int64, amount: Double) {
        guard let event = CGEvent(source: nil),
              let type = CGEventType(rawValue: Magnify.eventType),
              let subtypeField = CGEventField(rawValue: Magnify.subtypeField),
              let amountField = CGEventField(rawValue: Magnify.amountField),
              let phaseField = CGEventField(rawValue: Magnify.phaseField) else { return }
        event.type = type
        event.setIntegerValueField(subtypeField, value: Magnify.subtypeZoom)
        event.setIntegerValueField(phaseField, value: phase)
        event.setDoubleValueField(amountField, value: amount)
        event.setIntegerValueField(.eventSourceUserData, value: InputTap.syntheticTag)
        event.post(tap: .cghidEventTap)
    }

    /// İmlecin olduğu yere sentetik fare düğmesi tıklaması (isteğe bağlı düzenleyicilerle).
    private static func postButton(_ number: Int, flags: CGEventFlags = []) {
        let location = CGEvent(source: nil)?.location ?? .zero
        let source = CGEventSource(stateID: .hidSystemState)
        let button = CGMouseButton(rawValue: UInt32(number)) ?? .center
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                      mouseCursorPosition: location, mouseButton: button) else { continue }
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(number))
            if !flags.isEmpty { event.flags = flags }
            event.setIntegerValueField(.eventSourceUserData, value: InputTap.syntheticTag)
            event.post(tap: .cghidEventTap)
        }
    }

    /// Düzenleyici adlarının ("command", "option", "control", "shift", "fn") olay bayrakları.
    static func flags(forModifiers names: [String]) -> CGEventFlags {
        var flags: CGEventFlags = []
        for name in names {
            switch name {
            case "command": flags.insert(.maskCommand)
            case "option": flags.insert(.maskAlternate)
            case "control": flags.insert(.maskControl)
            case "shift": flags.insert(.maskShift)
            case "fn": flags.insert(.maskSecondaryFn)
            default: break
            }
        }
        return flags
    }

    private static func flags(for combo: KeyCombo) -> CGEventFlags {
        var flags = Self.flags(forModifiers: combo.modifiers)
        // Ok tuşları fn + sayısal tuş takımı bayraklarıyla gelir.
        if (123...126).contains(combo.keyCode) {
            flags.insert(.maskSecondaryFn)
            flags.insert(.maskNumericPad)
        }
        // Sayısal tuş takımı + / − tuşları.
        if combo.keyCode == 69 || combo.keyCode == 78 { flags.insert(.maskNumericPad) }
        return flags
    }

    private static func postKey(_ combo: KeyCombo) {
        let source = CGEventSource(stateID: .hidSystemState)
        let flags = flags(for: combo)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(combo.keyCode),
                                      keyDown: down) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: InputTap.syntheticTag)
            event.post(tap: .cghidEventTap)
        }
    }

    private static func openApp(path: String, name: String) {
        guard !path.isEmpty else {
            Log.write("Uygulama aç: yol boş (\(name))")
            return
        }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { Log.write("Uygulama açılamadı: \(name) · \(error.localizedDescription)") }
        }
    }

    private static func runShortcut(_ name: String) {
        guard !name.isEmpty else {
            Log.write("Kısayol çalıştır: ad boş")
            return
        }
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                Log.write("Kısayol çalıştı: \(name) · çıkış kodu \(process.terminationStatus)")
            } catch {
                Log.write("Kısayol başlatılamadı: \(name) · \(error.localizedDescription)")
            }
        }
    }
}
