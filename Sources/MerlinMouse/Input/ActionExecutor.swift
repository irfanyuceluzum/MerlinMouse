import AppKit
import CoreGraphics
import MerlinCore

/// Tüm `GestureAction` türlerini yürütür. Ana kuyruktan çağrılır; her sentetik olay işaretlenir.
enum ActionExecutor {
    static func run(_ action: GestureAction) {
        switch action {
        case .middleClick, .back, .forward:
            if let n = action.buttonNumber { postButton(n) }
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

    /// İmlecin olduğu yere sentetik fare düğmesi tıklaması.
    private static func postButton(_ number: Int) {
        let location = CGEvent(source: nil)?.location ?? .zero
        let source = CGEventSource(stateID: .hidSystemState)
        let button = CGMouseButton(rawValue: UInt32(number)) ?? .center
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                      mouseCursorPosition: location, mouseButton: button) else { continue }
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(number))
            event.setIntegerValueField(.eventSourceUserData, value: InputTap.syntheticTag)
            event.post(tap: .cghidEventTap)
        }
    }

    private static func flags(for combo: KeyCombo) -> CGEventFlags {
        var flags: CGEventFlags = []
        for name in combo.modifiers {
            switch name {
            case "command": flags.insert(.maskCommand)
            case "option": flags.insert(.maskAlternate)
            case "control": flags.insert(.maskControl)
            case "shift": flags.insert(.maskShift)
            case "fn": flags.insert(.maskSecondaryFn)
            default: break
            }
        }
        // Ok tuşları fn + sayısal tuş takımı bayraklarıyla gelir.
        if (123...126).contains(combo.keyCode) {
            flags.insert(.maskSecondaryFn)
            flags.insert(.maskNumericPad)
        }
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
