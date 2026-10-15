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

/// Atama ekleme / düzenleme sayfası: hazır hareket kartları, tek çakışma kartı, eylem ve kapsam.
struct BindingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let enabled: Bool
    private let isEditing: Bool
    private let original: GestureBinding?
    private let initialTrigger: Trigger
    private let initialScope: AppChoice?
    @State private var confirmChange = false
    @State private var confirmDelete = false
    @State private var trigger: Trigger
    @State private var picked = true
    @State private var custom: Bool
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
        isEditing = existing != nil
        original = existing
        let startScope: AppChoice?
        if let e = existing, let bid = e.appBundleID {
            startScope = AppChoice(id: bid, name: e.appName ?? bid)
        } else {
            startScope = presetScope
        }
        let start = existing?.trigger.normalized
            ?? TriggerOptions.firstFreeTrigger(among: BindingStore.shared.bindings, scope: startScope?.id,
                                               env: AppModel.shared.conflictEnvironment())
        initialTrigger = start
        initialScope = startScope
        _trigger = State(initialValue: start)
        _custom = State(initialValue: !GesturePresets.all.contains { $0.trigger == start.normalized })
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
        _scope = State(initialValue: startScope)
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

    private func binding(for t: Trigger) -> GestureBinding {
        GestureBinding(id: id, trigger: t, action: action, enabled: enabled,
                       appBundleID: scope?.id, appName: scope?.name, builtInKey: original?.builtInKey)
    }

    private var current: GestureBinding { binding(for: trigger) }

    private var isBuiltIn: Bool { original?.isBuiltIn ?? false }

    /// Temel hareketin tetiği ya da eylemi kaydedilmiş hâlinden farklı mı?
    private var builtInChanged: Bool {
        guard let o = original, o.isBuiltIn else { return false }
        return current.trigger.normalized != o.trigger.normalized || current.action != o.action
    }

    /// Kayıtlı atamadan herhangi bir fark var mı?
    private var dirty: Bool {
        guard let o = original else { return false }
        return current.trigger.normalized != o.trigger.normalized || current.action != o.action
            || current.appBundleID != o.appBundleID
    }

    /// Temel hareket değiştiyse önce onay ister.
    private func save() {
        if builtInChanged { confirmChange = true } else { commit() }
    }

    private func commit() {
        BindingStore.shared.upsert(current)
        dismiss()
    }

    /// Alanları verilen atamanın tetik, eylem ve kapsamına çeker (kaydetmez).
    private func load(_ b: GestureBinding) {
        loadTrigger(b.trigger.normalized)
        loadAction(b.action)
        if let bid = b.appBundleID { scope = AppChoice(id: bid, name: b.appName ?? bid) } else { scope = nil }
    }

    private func loadTrigger(_ t: Trigger) {
        trigger = t
        custom = !GesturePresets.all.contains { $0.trigger == t.normalized }
        picked = true
    }

    private func loadAction(_ a: GestureAction) {
        switch a {
        case .middleClick: kind = .middle
        case .back: kind = .back
        case .forward: kind = .forward
        case .shortcut(let c): kind = .shortcut; combo = c
        case .system(let x): kind = .system; sysAction = x
        case .openApp(let p, let n): kind = .openApp; appPath = p; appName = n
        case .runShortcut(let n): kind = .runShortcut; shortcutName = n
        }
    }

    private func resetFields() {
        if let o = original {
            if o.isBuiltIn {
                var d = DefaultBindings.resetToDefault(o)
                d.appBundleID = scope?.id; d.appName = scope?.name
                loadTrigger(d.trigger.normalized)
                loadAction(d.action)
            } else {
                load(o)
            }
        } else {
            loadTrigger(initialTrigger)
            loadAction(.middleClick)
            scope = initialScope
        }
    }

    var body: some View {
        let result = BindingValidation.evaluate(current, among: BindingStore.shared.bindings, env: env)
        let mode = BindingValidation.saveMode(conflicts: result.conflicts, missing: result.missing)
        let canSave = picked && mode != .blocked
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(isEditing ? "Hareketi düzenle" : "Yeni hareket ekle")
                                .font(.system(size: 18, weight: .semibold)).foregroundStyle(MM.text)
                            if isBuiltIn {
                                HStack(spacing: 3) {
                                    Image(systemName: "lock.fill").font(.system(size: 9, weight: .semibold))
                                    Text("Temel hareket").font(.system(size: 11.5, weight: .medium))
                                }
                                .foregroundStyle(MM.text2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(MM.neuBg, in: Capsule())
                            }
                        }
                        Text("Bir hareket seç. Merlin Mouse onu macOS ve BetterTouchTool atamalarıyla karşılaştırır.")
                            .font(.system(size: 13)).foregroundStyle(MM.text2)
                    }
                    .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)

                    if builtInChanged {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle").font(.system(size: 14, weight: .semibold))
                            Text("Temel bir hareketi değiştiriyorsun. Varsayılan davranış değişir; 'Varsayılana sıfırla' ile geri alabilirsin.")
                                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(MM.warnText)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MM.warnBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.horizontal, 24).padding(.bottom, 12)
                    }

                    cardGrid.padding(.horizontal, 24)
                    if custom && picked { customFields.padding(.horizontal, 24).padding(.top, 12) }

                    conflictArea(result.conflicts).padding(.horizontal, 24).padding(.top, 16)

                    VStack(spacing: 12) {
                        MMCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                MMSectionLabel("Eylem")
                                actionFields
                                if let m = result.missing {
                                    Text(m).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(MM.warnText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        MMCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                MMSectionLabel("Kapsam")
                                scopeField
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 16)
                }
            }
            HStack(spacing: 10) {
                if isBuiltIn {
                    MMSecondaryButton("Varsayılana sıfırla") { resetFields() }
                } else if isEditing {
                    MMSecondaryButton("Değişiklikleri geri al") { resetFields() }
                        .disabled(!dirty).opacity(dirty ? 1 : 0.4)
                    smallButton("Sil", ink: .red) { confirmDelete = true }
                } else {
                    MMSecondaryButton("Sıfırla") { resetFields() }
                }
                Spacer()
                MMSecondaryButton("Vazgeç") { dismiss() }.keyboardShortcut(.cancelAction)
                MMPrimaryButton(isEditing ? "Kaydet" : "Ekle") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave).opacity(canSave ? 1 : 0.4)
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(MM.card2)
            .overlay(alignment: .top) { Rectangle().fill(MM.line).frame(height: 1) }
        }
        .frame(width: 820, height: 700)
        .background(MM.card)
        .onAppear { env = AppModel.shared.conflictEnvironment() }
        .confirmationDialog("Temel hareketi değiştir?", isPresented: $confirmChange) {
            Button("Değiştir") { commit() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Varsayılan davranış değişir. İstediğin zaman 'Varsayılana sıfırla' ile geri alabilirsin.")
        }
        .confirmationDialog("Bu atama silinsin mi?", isPresented: $confirmDelete) {
            Button("Sil", role: .destructive) {
                BindingStore.shared.remove(id: id)
                dismiss()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("\(trigger.title) → \(action.title)")
        }
    }

    // MARK: Kart ızgarası

    private func cardStatus(_ t: Trigger) -> (text: String, dot: Color) {
        let conflicts = ConflictChecker.check(binding(for: t), among: BindingStore.shared.bindings, env: env)
        switch BindingValidation.heaviest(conflicts)?.level {
        case .reserved, .unsupported: return ("Ayrılmış", MM.text2)
        case .duplicate: return ("Zaten atanmış", MM.text2)
        case .replacesDisabled: return ("Kapalı ataması var", MM.text2)
        case .macOS: return ("macOS kullanıyor", MM.warnDot)
        case .btt: return ("BetterTouchTool'da atanmış", MM.bttDot)
        default: return ("Serbest", MM.accent)
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(Array(GesturePresets.all.enumerated()), id: \.offset) { _, p in
                let st = cardStatus(p.trigger)
                gestureCard(title: p.title, status: st.text, dot: st.dot,
                            selected: picked && !custom && trigger.normalized == p.trigger) {
                    trigger = p.trigger
                    custom = false
                    picked = true
                }
            }
            gestureCard(title: "Özel hareket…", status: "Tür, parmak ve bölgeyi kendin seç", dot: nil,
                        selected: picked && custom) {
                custom = true
                picked = true
            }
        }
    }

    private func gestureCard(title: String, status: String, dot: Color?, selected: Bool,
                             action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(MM.text).lineLimit(1)
                    Spacer(minLength: 0)
                    if let dot { Circle().fill(dot).frame(width: 10, height: 10) }
                }
                Text(status).font(.system(size: 12)).foregroundStyle(MM.text2).lineLimit(1)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .background(selected ? MM.accentSoft : MM.card, in: shape)
            .overlay(shape.strokeBorder(selected ? MM.accent : MM.line, lineWidth: selected ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Özel hareket

    @ViewBuilder private var customFields: some View {
        let zones = TriggerOptions.zoneChoices(kind: trigger.kind, fingers: trigger.fingers, modifier: trigger.modifier)
        let reason = TriggerOptions.unavailableZoneReason(kind: trigger.kind, fingers: trigger.fingers,
                                                          modifier: trigger.modifier)
        MMCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                MMSectionLabel("Özel hareket")
                triggerFields
                if zones.isEmpty, let reason {
                    Text(reason).font(.system(size: 12)).foregroundStyle(MM.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Çakışma alanı

    private func ownerName(_ c: Conflict) -> String {
        c.title.hasPrefix("macOS ") ? String(c.title.dropFirst(6)) : c.title
    }

    private func smallButton(_ title: String, fill: Color? = nil, ink: Color = MM.text, border: Color? = nil,
                             underline: Bool = false, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Button(action: action) {
            Text(title).font(.system(size: 13, weight: fill != nil ? .medium : .regular))
                .underline(underline).foregroundStyle(ink)
                .padding(.horizontal, 14).frame(height: 36)
                .background(fill ?? Color.clear, in: shape)
                .overlay { if let border { shape.strokeBorder(border, lineWidth: 1) } }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private func clearPick() { picked = false; custom = false }

    private func conflictCard<B: View>(icon: String, bg: Color, line: Color, fg: Color, title: String, detail: String,
                              @ViewBuilder buttons: () -> B) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(fg)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(fg)
                    Text(detail).font(.system(size: 13)).foregroundStyle(fg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) { buttons() }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg, in: shape)
        .overlay(shape.strokeBorder(line, lineWidth: 1))
    }

    @ViewBuilder private func conflictArea(_ conflicts: [Conflict]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            conflictMain(conflicts)
            if picked, let c = BindingValidation.heaviest(conflicts), c.level != .replacesDisabled, c.level != .duplicate,
               let notice = BindingValidation.removalNotice(conflicts: conflicts) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 14, weight: .semibold))
                    Text(notice).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(MM.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MM.neuBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    @ViewBuilder private func conflictMain(_ conflicts: [Conflict]) -> some View {
        if !picked {
            Text("Yukarıdan bir hareket seç.").font(.system(size: 13)).foregroundStyle(MM.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let c = BindingValidation.heaviest(conflicts) {
            switch c.level {
            case .macOS:
                conflictCard(icon: "exclamationmark.triangle", bg: MM.warnBg, line: MM.warnLine, fg: MM.warnText,
                             title: "macOS bu hareketi kullanıyor: \(ownerName(c))",
                             detail: "Yer: Sistem Ayarları › Fare. Atarsan iki eylem aynı anda çalışır.") {
                    smallButton("Farklı hareket seç", fill: MM.warnText, ink: MM.accentInk) { clearPick() }
                    smallButton("macOS'ta kapat…", fill: MM.card, border: MM.warnLine) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Mouse-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    smallButton("Yine de ata", ink: MM.warnText, underline: true) { save() }
                        .disabled(!canSaveNow(conflicts))
                }
            case .btt:
                conflictCard(icon: "arrow.left.arrow.right", bg: MM.bttBg, line: MM.bttLine, fg: MM.bttText,
                             title: "BetterTouchTool bu hareketi kullanıyor", detail: c.detail) {
                    smallButton("Farklı hareket seç", fill: MM.card, border: MM.bttLine) { clearPick() }
                    smallButton("Yine de ata", ink: MM.bttText, underline: true) { save() }
                        .disabled(!canSaveNow(conflicts))
                }
            case .duplicate:
                let rival = BindingStore.shared.bindings.first {
                    $0.id != id && $0.enabled && $0.appBundleID == scope?.id && $0.trigger.normalized == trigger.normalized
                }
                let rivalIsBuiltIn = rival?.isBuiltIn ?? false
                conflictCard(icon: "square.on.square", bg: MM.neuBg, line: MM.line, fg: MM.text,
                             title: "Bu hareket zaten '\(rival?.action.title ?? "başka bir")' eylemine atanmış",
                             detail: c.detail) {
                    smallButton("Farklı hareket seç", fill: MM.card, border: MM.line) { clearPick() }
                    smallButton(rivalIsBuiltIn ? "Temeli kapatıp ata" : "Öncekinin yerine geçir", fill: MM.accent, ink: MM.accentInk) { save() }
                        .disabled(!canSaveNow(conflicts))
                }
            case .replacesDisabled:
                conflictCard(icon: "arrow.triangle.2.circlepath", bg: MM.neuBg, line: MM.line, fg: MM.text,
                             title: c.title, detail: c.detail) {
                    smallButton("Farklı hareket seç", fill: MM.card, border: MM.line) { clearPick() }
                    smallButton("Yerine geçerek ekle", fill: MM.accent, ink: MM.accentInk) { save() }
                        .disabled(!canSaveNow(conflicts))
                }
            case .reserved, .unsupported:
                conflictCard(icon: "lock", bg: MM.neuBg, line: MM.line, fg: MM.text,
                             title: "Ayrılmış: \(c.title)", detail: c.detail) { EmptyView() }
            case .shadows:
                conflictCard(icon: "info.circle", bg: MM.accentSoft, line: MM.accentLine, fg: MM.accentText,
                             title: "Genel atamayı ezer", detail: c.detail) { EmptyView() }
            case .caution:
                conflictCard(icon: "exclamationmark.triangle", bg: MM.warnBg, line: MM.warnLine, fg: MM.warnText,
                             title: c.title, detail: c.detail) { EmptyView() }
            }
        } else {
            conflictCard(icon: "checkmark", bg: MM.accentSoft, line: MM.accentLine, fg: MM.accentText,
                         title: "Bu hareket serbest", detail: "macOS'ta ve BetterTouchTool'da atanmış değil.") { EmptyView() }
        }
    }

    /// "Yine de ata" gibi düğmeler de eksik eylemde kaydetmez.
    private func canSaveNow(_ conflicts: [Conflict]) -> Bool {
        let missing = BindingValidation.evaluate(current, among: BindingStore.shared.bindings, env: env).missing
        return BindingValidation.saveMode(conflicts: conflicts, missing: missing) != .blocked
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
        case .rear: return "Arka (logo)"
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
        if isBuiltIn {
            Picker("Kapsam", selection: .constant("")) {
                Text("Tüm uygulamalar").tag("")
            }
            .disabled(true)
            Text("Temel hareketler tüm uygulamalarda geçerlidir. Bir uygulamaya özel davranış için Uygulama profillerinden yeni hareket ekle.")
                .font(.system(size: 12)).foregroundStyle(MM.text2)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            scopePicker
        }
    }

    @ViewBuilder private var scopePicker: some View {
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
