import SwiftUI
import AppKit
import UniformTypeIdentifiers
import MerlinCore

/// Kapsam / uygulama seçimi için kimlik + ad.
struct AppChoice: Identifiable, Hashable {
    var id: String
    var name: String
}

struct PickedApp {
    var path: String
    var name: String
    var bundleID: String?
}

enum AppPicker {
    /// Çalışan normal uygulamalar.
    static func runningApps() -> [AppChoice] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppChoice? in
                guard let id = app.bundleIdentifier, seen.insert(id).inserted else { return nil }
                return AppChoice(id: id, name: app.localizedName ?? id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Uygulama seçim paneli (.app).
    static func pickApp() -> PickedApp? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Seç"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let bundle = Bundle(url: url)
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return PickedApp(path: url.path, name: name, bundleID: bundle?.bundleIdentifier)
    }
}

/// `shortcuts list` çıktısı; süreç ana iş parçacığı dışında çalışır.
enum ShortcutsCLI {
    static func list(_ done: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["list"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            var names: [String] = []
            do {
                try p.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                names = String(decoding: data, as: UTF8.self)
                    .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } catch {}
            DispatchQueue.main.async { done(names) }
        }
    }
}

private enum EditorActionKind: String, CaseIterable, Identifiable {
    case middle, back, forward, shortcut, system, openApp, runShortcut
    var id: String { rawValue }
    var title: String {
        switch self {
        case .middle: return "Orta tıklama"
        case .back: return "Geri"
        case .forward: return "İleri"
        case .shortcut: return "Klavye kısayolu"
        case .system: return "Sistem eylemi"
        case .openApp: return "Uygulama aç"
        case .runShortcut: return "Kestirme çalıştır"
        }
    }
}

/// Atama ekleme / düzenleme sayfası.
struct BindingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let enabled: Bool
    @State private var trigger: Trigger
    @State private var kind: EditorActionKind
    @State private var combo: KeyCombo
    @State private var sysAction: SystemAction
    @State private var appPath: String
    @State private var appName: String
    @State private var shortcutName: String
    @State private var scope: AppChoice?
    @State private var shortcutList: [String] = []
    @State private var env = AppModel.shared.conflictEnvironment()
    @State private var running = AppPicker.runningApps()

    private static let otherTag = "__other__"

    init(existing: GestureBinding?, presetScope: AppChoice? = nil) {
        id = existing?.id ?? UUID()
        enabled = existing?.enabled ?? true
        _trigger = State(initialValue: existing?.trigger
                         ?? TriggerOptions.sanitize(Trigger(kind: .press, fingers: 1, zone: .center)))
        var k = EditorActionKind.middle
        var c = KeyCombo(keyCode: 0, modifiers: [], display: "")
        var s = SystemAction.missionControl
        var path = "", name = "", sc = ""
        switch existing?.action ?? .middleClick {
        case .middleClick: k = .middle
        case .back: k = .back
        case .forward: k = .forward
        case .shortcut(let combo): k = .shortcut; c = combo
        case .system(let a): k = .system; s = a
        case .openApp(let p, let n): k = .openApp; path = p; name = n
        case .runShortcut(let n): k = .runShortcut; sc = n
        }
        _kind = State(initialValue: k)
        _combo = State(initialValue: c)
        _sysAction = State(initialValue: s)
        _appPath = State(initialValue: path)
        _appName = State(initialValue: name)
        _shortcutName = State(initialValue: sc)
        if let e = existing, let bid = e.appBundleID {
            _scope = State(initialValue: AppChoice(id: bid, name: e.appName ?? bid))
        } else {
            _scope = State(initialValue: presetScope)
        }
    }

    private var action: GestureAction {
        switch kind {
        case .middle: return .middleClick
        case .back: return .back
        case .forward: return .forward
        case .shortcut: return .shortcut(combo)
        case .system: return .system(sysAction)
        case .openApp: return .openApp(path: appPath, name: appName)
        case .runShortcut: return .runShortcut(name: shortcutName)
        }
    }

    private var current: GestureBinding {
        GestureBinding(id: id, trigger: trigger, action: action, enabled: enabled,
                       appBundleID: scope?.id, appName: scope?.name)
    }

    var body: some View {
        let result = BindingValidation.evaluate(current, among: BindingStore.shared.bindings, env: env)
        VStack(spacing: 0) {
            Form {
                Section("Tetik") { triggerFields }
                Section("Eylem") { actionFields }
                Section("Kapsam") { scopeField }
                Section("Denetim") {
                    if result.conflicts.isEmpty && result.missing == nil {
                        Text("Çakışma yok.").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(Array(result.conflicts.enumerated()), id: \.offset) { _, c in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.title).font(.callout.weight(.semibold))
                                .foregroundStyle(ConflictStyle.color(c.level))
                            Text(c.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let m = result.missing {
                        Text(m).font(.callout.weight(.semibold)).foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Vazgeç") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Kaydet") {
                    BindingStore.shared.upsert(current)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!result.canSave)
            }
            .padding(12)
        }
        .frame(width: 540, height: 640)
        .onAppear { env = AppModel.shared.conflictEnvironment() }
    }

    // MARK: Tetik

    private func field<T>(_ kp: WritableKeyPath<Trigger, T>) -> Binding<T> {
        Binding(get: { trigger[keyPath: kp] },
                set: { var t = trigger; t[keyPath: kp] = $0; trigger = TriggerOptions.sanitize(t) })
    }

    @ViewBuilder private var triggerFields: some View {
        Picker("Hareket türü", selection: field(\.kind)) {
            ForEach(TriggerOptions.editableKinds, id: \.self) { Text(Self.kindName($0)).tag($0) }
        }
        if trigger.modifier == .none {
            Picker("Parmak", selection: field(\.fingers)) {
                ForEach(TriggerOptions.fingerChoices(kind: trigger.kind), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
        }
        let zones = TriggerOptions.zoneChoices(kind: trigger.kind, fingers: trigger.fingers, modifier: trigger.modifier)
        if !zones.isEmpty {
            Picker("Bölge", selection: field(\.zone)) {
                ForEach(zones, id: \.self) { Text(Self.zoneName($0)).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        let mods = TriggerOptions.modifierChoices(kind: trigger.kind)
        if mods.count > 1 {
            Picker("Tuş", selection: field(\.modifier)) {
                ForEach(mods, id: \.self) { Text(Self.modifierName($0)).tag($0) }
            }
        }
        if trigger.kind == .swipe {
            Picker("Yön", selection: field(\.direction)) {
                ForEach(SwipeDirection.allCases, id: \.self) { Text(Self.directionName($0)).tag($0) }
            }
        }
    }

    private static func kindName(_ k: GestureKind) -> String {
        switch k {
        case .press: return "Bas"
        case .tap: return "Dokun"
        case .doubleTap: return "Çift dokun"
        case .swipe: return "Kaydır"
        case .hold: return "Basılı tut"
        }
    }

    private static func zoneName(_ z: Zone) -> String {
        switch z {
        case .any: return "Herhangi"
        case .left: return "Sol"
        case .center: return "Orta"
        case .right: return "Sağ"
        }
    }

    private static func modifierName(_ m: PressModifier) -> String {
        switch m {
        case .none: return "Yok"
        case .fn: return "Fn"
        case .option: return "⌥ Option"
        case .command: return "⌘ Command"
        case .shift: return "⇧ Shift"
        }
    }

    private static func directionName(_ d: SwipeDirection) -> String {
        switch d {
        case .up: return "Yukarı (öne)"
        case .down: return "Aşağı"
        case .left: return "Sola"
        case .right: return "Sağa"
        }
    }

    // MARK: Eylem

    @ViewBuilder private var actionFields: some View {
        Picker("Eylem", selection: $kind) {
            ForEach(EditorActionKind.allCases) { Text($0.title).tag($0) }
        }
        switch kind {
        case .shortcut:
            LabeledContent("Kısayol") { ShortcutRecorder(combo: $combo) }
        case .system:
            Picker("Sistem eylemi", selection: $sysAction) {
                ForEach(SystemAction.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        case .openApp:
            LabeledContent("Uygulama") {
                Button(appName.isEmpty ? "Seç…" : appName) {
                    if let p = AppPicker.pickApp() { appPath = p.path; appName = p.name }
                }
            }
        case .runShortcut:
            HStack {
                TextField("Kestirme adı", text: $shortcutName)
                Menu("Seç") {
                    if shortcutList.isEmpty { Text("Kestirme bulunamadı") }
                    ForEach(shortcutList, id: \.self) { n in Button(n) { shortcutName = n } }
                }
                .fixedSize()
            }
            .onAppear { if shortcutList.isEmpty { ShortcutsCLI.list { shortcutList = $0 } } }
        default:
            EmptyView()
        }
    }

    // MARK: Kapsam

    private var scopeOptions: [AppChoice] {
        var list = running
        if let s = scope, !list.contains(where: { $0.id == s.id }) { list.append(s) }
        return list
    }

    @ViewBuilder private var scopeField: some View {
        Picker("Kapsam", selection: Binding<String>(
            get: { scope?.id ?? "" },
            set: { v in
                if v == Self.otherTag {
                    if let p = AppPicker.pickApp(), let bid = p.bundleID {
                        scope = AppChoice(id: bid, name: p.name)
                    }
                } else if v.isEmpty {
                    scope = nil
                } else {
                    scope = scopeOptions.first { $0.id == v }
                }
            })) {
            Text("Tüm uygulamalar").tag("")
            ForEach(scopeOptions) { Text($0.name).tag($0.id) }
            Divider()
            Text("Diğer uygulama…").tag(Self.otherTag)
        }
    }
}
