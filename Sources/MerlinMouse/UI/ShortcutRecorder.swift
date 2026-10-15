import SwiftUI
import AppKit
import MerlinCore

/// Tıklayınca bir sonraki tuş vuruşunu kısayol olarak kaydeder.
struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(label).frame(minWidth: 150)
        }
        .tint(recording ? Color.merlinWarn : nil)
        .onDisappear { stop() }
    }

    private var label: String {
        if recording { return L("Bir tuşa bas… (Esc: iptal)") }
        return combo.display.isEmpty ? L("Kaydetmek için tıkla") : combo.display
    }

    private func start() {
        stop()
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let plain = event.modifierFlags.intersection([.control, .option, .shift, .command, .function]).isEmpty
            if event.keyCode == 53 && plain {
                stop()
                return nil
            }
            combo = Self.combo(from: event)
            stop()
            return nil
        }
    }

    /// Monitörü her durumda kaldırır.
    private func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        recording = false
    }

    /// Tuş adları kaydedildiği andaki dilde saklanır (KeyCombo.display).
    private static var keyNames: [UInt16: String] { [
        123: "←", 124: "→", 125: "↓", 126: "↑",
        49: L("Boşluk"), 36: "↩", 76: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ] }

    static func combo(from event: NSEvent) -> KeyCombo {
        let flags = event.modifierFlags
        let names = keyNames
        let name = names[event.keyCode]
            ?? event.charactersIgnoringModifiers?.uppercased().trimmingCharacters(in: .whitespaces)
            ?? ""
        let keyName = name.isEmpty ? LF("Tuş %lld", Int(event.keyCode)) : name
        // Ok ve F tuşları fn bayrağını kendiliğinden taşır; onu sayma.
        let fnKey = flags.contains(.function) && names[event.keyCode] == nil
        var mods: [String] = []
        var shown = ""
        if flags.contains(.control) { mods.append("control"); shown += "⌃" }
        if flags.contains(.option) { mods.append("option"); shown += "⌥" }
        if flags.contains(.shift) { mods.append("shift"); shown += "⇧" }
        if flags.contains(.command) { mods.append("command"); shown += "⌘" }
        if fnKey { mods.append("fn"); shown = "fn " + shown }
        return KeyCombo(keyCode: event.keyCode, modifiers: mods, display: shown + keyName)
    }
}
