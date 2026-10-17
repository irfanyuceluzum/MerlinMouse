import SwiftUI
import AppKit
import MerlinCore

/// Atama ekleme / düzenleme sayfası: hazır hareket kartları, tek çakışma kartı, eylem ve kapsam.
struct BindingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let enabled: Bool
    private let isEditing: Bool
    private let original: GestureBinding?
    private let initialTrigger: Trigger
    private let initialScope: AppChoice?
    /// Atamanın aygıtı: mevcut atamada onunki, yenide çağıranın verdiği (varsayılan Magic Mouse).
    private let device: InputDeviceKind
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
    /// Düzenleyicili orta tuşun tuşları (⌃⌥⇧⌘ sırasıyla).
    @State private var dragMods: [String]
    /// Yakınlaştırma yöntemi (varsayılan trackpad hareketi).
    @State private var zoomStyle: ZoomStyle
    /// Yakınlaştırmada tekerlekle birlikte tutulan isteğe bağlı tuşlar (yalnız `wheel`; varsayılan hiçbiri).
    @State private var zoomMods: [String]
    /// Kısayol çiftinin artırma ve azaltma kısayolları.
    @State private var pairUp: KeyCombo
    @State private var pairDown: KeyCombo
    @State private var scope: AppChoice?
    @State private var shortcutList: [String] = []
    @State private var env = AppModel.shared.conflictEnvironment()
    @State private var running = AppPicker.runningApps()

    private static let otherTag = "__other__"

    /// `presetAction` verilirse alanlar kayıtlı eylem yerine onunla açılır (örn. Kaydırma sayfasında
    /// "Kısayol çifti…" seçildiğinde); kaydedilene kadar hiçbir şey değişmez. `device` yalnız yeni atamada
    /// kullanılır; mevcut atama kendi aygıtında kalır.
    init(existing: GestureBinding?, presetScope: AppChoice? = nil, presetAction: GestureAction? = nil,
         device: InputDeviceKind = .magicMouse) {
        let dev = existing?.device ?? device
        self.device = dev
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
                                               env: AppModel.shared.conflictEnvironment(), device: dev)
        initialTrigger = start
        initialScope = startScope
        _trigger = State(initialValue: start)
        _custom = State(initialValue: !EditorTriggerGrid.isPreset(start, device: dev))
        var k = EditorActionKind.middle
        var c = KeyCombo(keyCode: 0, modifiers: [], display: "")
        var s = SystemAction.missionControl
        var path = "", name = "", sc = ""
        var mods = ["shift"]
        var zMods: [String] = []
        var zStyle = ZoomStyle.gesture
        var pUp = Self.emptyCombo, pDown = Self.emptyCombo
        switch presetAction ?? existing?.action ?? .middleClick {
        case .middleClick: k = .middle
        case .middleDrag(let m): k = .middleDrag; mods = GestureAction.normalizedModifiers(m)
        case .zoom(let st, let m): k = .zoom; zStyle = st; zMods = GestureAction.zoomModifiers(m, style: st)
        case .back: k = .back
        case .forward: k = .forward
        case .shortcut(let combo): k = .shortcut; c = combo
        case .system(let a): k = .system; s = a
        case .openApp(let p, let n): k = .openApp; path = p; name = n
        case .runShortcut(let n): k = .runShortcut; sc = n
        case .volume: k = .volume
        case .brightness: k = .brightness
        case .stepShortcut(let u, let d): k = .pair; pUp = u; pDown = d
        }
        _kind = State(initialValue: k)
        _dragMods = State(initialValue: mods)
        _zoomStyle = State(initialValue: zStyle)
        _zoomMods = State(initialValue: zMods)
        _pairUp = State(initialValue: pUp)
        _pairDown = State(initialValue: pDown)
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
        case .middleDrag: return .middleDrag(modifiers: GestureAction.normalizedModifiers(dragMods))
        case .zoom: return .zoom(style: zoomStyle, modifiers: GestureAction.zoomModifiers(zoomMods, style: zoomStyle))
        case .back: return .back
        case .forward: return .forward
        case .shortcut: return .shortcut(combo)
        case .system: return .system(sysAction)
        case .openApp: return .openApp(path: appPath, name: appName)
        case .runShortcut: return .runShortcut(name: shortcutName)
        case .volume: return .volume
        case .brightness: return .brightness
        case .pair: return .stepShortcut(up: pairUp, down: pairDown)
        }
    }

    private static let emptyCombo = KeyCombo(keyCode: 0, modifiers: [], display: "")

    private func binding(for t: Trigger) -> GestureBinding {
        // Aygıt korunur: trackpad ataması düzenlenince fare atamasına dönüşmesin (`device` = original?.device ?? verilen).
        GestureBinding(id: id, trigger: t, action: action, enabled: enabled,
                       appBundleID: scope?.id, appName: scope?.name, builtInKey: original?.builtInKey,
                       device: original?.device ?? device)
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
        custom = !EditorTriggerGrid.isPreset(t, device: device)
        picked = true
    }

    private func loadAction(_ a: GestureAction) {
        // Yakınlaştırma dışındaki eylemlerde yöntem varsayılana döner.
        zoomStyle = .gesture
        zoomMods = []
        switch a {
        case .middleClick: kind = .middle
        case .middleDrag(let m): kind = .middleDrag; dragMods = GestureAction.normalizedModifiers(m)
        case .zoom(let st, let m): kind = .zoom; zoomStyle = st; zoomMods = GestureAction.zoomModifiers(m, style: st)
        case .back: kind = .back
        case .forward: kind = .forward
        case .shortcut(let c): kind = .shortcut; combo = c
        case .system(let x): kind = .system; sysAction = x
        case .openApp(let p, let n): kind = .openApp; appPath = p; appName = n
        case .runShortcut(let n): kind = .runShortcut; shortcutName = n
        case .volume: kind = .volume
        case .brightness: kind = .brightness
        case .stepShortcut(let u, let d): kind = .pair; pairUp = u; pairDown = d
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
                            Text(isEditing ? L("Hareketi düzenle") : L("Yeni hareket ekle"))
                                .font(.system(size: 18, weight: .semibold)).foregroundStyle(MM.text)
                            if device == .trackpad {
                                HStack(spacing: 4) {
                                    Image(systemName: "rectangle.and.hand.point.up.left").font(.system(size: 9, weight: .semibold))
                                    Text(InputDeviceKind.trackpad.displayName).font(.system(size: 11.5, weight: .medium))
                                }
                                .foregroundStyle(MM.accentText)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(MM.accentSoft, in: Capsule())
                            }
                            if isBuiltIn {
                                HStack(spacing: 3) {
                                    Image(systemName: "lock.fill").font(.system(size: 9, weight: .semibold))
                                    Text(L("Temel hareket")).font(.system(size: 11.5, weight: .medium))
                                }
                                .foregroundStyle(MM.text2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(MM.neuBg, in: Capsule())
                            }
                        }
                        Text(L("Bir hareket seç. Merlin Mouse onu macOS ve BetterTouchTool atamalarıyla karşılaştırır."))
                            .font(.system(size: 13)).foregroundStyle(MM.text2)
                    }
                    .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)

                    if builtInChanged {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle").font(.system(size: 14, weight: .semibold))
                            Text(L("Temel bir hareketi değiştiriyorsun. Varsayılan davranış değişir; 'Varsayılana sıfırla' ile geri alabilirsin."))
                                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(MM.warnText)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MM.warnBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.horizontal, 24).padding(.bottom, 12)
                    }

                    EditorTriggerGrid(device: device, kind: kind, env: env, makeBinding: binding(for:),
                                      trigger: $trigger, custom: $custom, picked: $picked)
                        .padding(.horizontal, 24)
                    if custom && picked { customFields.padding(.horizontal, 24).padding(.top, 12) }

                    conflictArea(result.conflicts).padding(.horizontal, 24).padding(.top, 16)

                    VStack(spacing: 12) {
                        MMCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                MMSectionLabel(L("Eylem"))
                                EditorActionPicker(triggerKind: trigger.kind, kind: $kind, combo: $combo,
                                                   sysAction: $sysAction, appPath: $appPath, appName: $appName,
                                                   shortcutName: $shortcutName, dragMods: $dragMods,
                                                   zoomStyle: $zoomStyle, zoomMods: $zoomMods,
                                                   pairUp: $pairUp, pairDown: $pairDown, shortcutList: $shortcutList)
                                if let m = result.missing {
                                    Text(m).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(MM.warnText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        MMCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                MMSectionLabel(L("Kapsam"))
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
                    MMSecondaryButton(L("Varsayılana sıfırla")) { resetFields() }
                } else if isEditing {
                    MMSecondaryButton(L("Değişiklikleri geri al")) { resetFields() }
                        .disabled(!dirty).opacity(dirty ? 1 : 0.4)
                    smallButton(L("Sil"), ink: .red) { confirmDelete = true }
                } else {
                    MMSecondaryButton(L("Sıfırla")) { resetFields() }
                }
                Spacer()
                MMSecondaryButton(L("Vazgeç")) { dismiss() }.keyboardShortcut(.cancelAction)
                MMPrimaryButton(isEditing ? L("Kaydet") : L("Ekle")) { save() }
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
        // Çimdikleme yalnız yakınlaştırmaya, kenar kaydırma yalnız adım eylemlerine atanır; uymayan eylem
        // türe göre varsayılana döner (çimdikleme → yakınlaştırma, kenar → ses, diğerleri → orta tıklama).
        .onChange(of: trigger.kind) { _, newKind in
            guard !EditorActionKind.choices(for: newKind).contains(kind) else { return }
            switch newKind {
            case .pinch: kind = .zoom
            case .edgeSlide: kind = .volume
            default: kind = .middle
            }
        }
        .onChange(of: kind) { _, newKind in
            if newKind == .middleDrag, dragMods.isEmpty { dragMods = ["shift"] }
        }
        .confirmationDialog(L("Temel hareketi değiştir?"), isPresented: $confirmChange) {
            Button(L("Değiştir")) { commit() }
            Button(L("Vazgeç"), role: .cancel) {}
        } message: {
            Text(L("Varsayılan davranış değişir. İstediğin zaman 'Varsayılana sıfırla' ile geri alabilirsin."))
        }
        .confirmationDialog(L("Bu atama silinsin mi?"), isPresented: $confirmDelete) {
            Button(L("Sil"), role: .destructive) {
                BindingStore.shared.remove(id: id)
                dismiss()
            }
            Button(L("Vazgeç"), role: .cancel) {}
        } message: {
            Text(verbatim: "\(trigger.title) → \(action.title)")
        }
    }

    // MARK: Özel hareket

    @ViewBuilder private var customFields: some View {
        let zones = TriggerOptions.zoneChoices(kind: trigger.kind, fingers: trigger.fingers, modifier: trigger.modifier,
                                               device: device)
        let reason = TriggerOptions.unavailableZoneReason(kind: trigger.kind, fingers: trigger.fingers,
                                                          modifier: trigger.modifier, device: device)
        MMCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                MMSectionLabel(L("Özel hareket"))
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
            Text(L("Yukarıdan bir hareket seç.")).font(.system(size: 13)).foregroundStyle(MM.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let c = BindingValidation.heaviest(conflicts) {
            switch c.level {
            case .macOS:
                conflictCard(icon: "exclamationmark.triangle", bg: MM.warnBg, line: MM.warnLine, fg: MM.warnText,
                             title: LF("macOS bu hareketi kullanıyor: %@", ownerName(c)),
                             detail: device == .trackpad
                                ? L("Yer: Sistem Ayarları › Trackpad. Atarsan iki eylem aynı anda çalışır.")
                                : L("Yer: Sistem Ayarları › Fare. Atarsan iki eylem aynı anda çalışır.")) {
                    smallButton(L("Farklı hareket seç"), fill: MM.warnText, ink: MM.accentInk) { clearPick() }
                    smallButton(L("macOS'ta kapat…"), fill: MM.card, border: MM.warnLine) {
                        let pane = device == .trackpad ? "com.apple.Trackpad-Settings.extension"
                                                       : "com.apple.Mouse-Settings.extension"
                        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    smallButton(L("Yine de ata"), ink: MM.warnText, underline: true) { save() }
                        .disabled(!canSaveNow(conflicts))
                }
            case .btt:
                conflictCard(icon: "arrow.left.arrow.right", bg: MM.bttBg, line: MM.bttLine, fg: MM.bttText,
                             title: L("BetterTouchTool bu hareketi kullanıyor"), detail: c.detail) {
                    smallButton(L("Farklı hareket seç"), fill: MM.card, border: MM.bttLine) { clearPick() }
                    smallButton(L("Yine de ata"), ink: MM.bttText, underline: true) { save() }
                        .disabled(!canSaveNow(conflicts))
                }
            case .duplicate:
                let rival = BindingStore.shared.bindings.first {
                    $0.id != id && $0.enabled && $0.device == device && $0.appBundleID == scope?.id
                        && $0.trigger.normalized == trigger.normalized
                }
                let rivalIsBuiltIn = rival?.isBuiltIn ?? false
                conflictCard(icon: "square.on.square", bg: MM.neuBg, line: MM.line, fg: MM.text,
                             title: LF("Bu hareket zaten '%@' eylemine atanmış", rival?.action.title ?? L("başka bir")),
                             detail: c.detail) {
                    smallButton(L("Farklı hareket seç"), fill: MM.card, border: MM.line) { clearPick() }
                    smallButton(rivalIsBuiltIn ? L("Temeli kapatıp ata") : L("Öncekinin yerine geçir"), fill: MM.accent, ink: MM.accentInk) { save() }
                        .disabled(!canSaveNow(conflicts))
                }
            case .replacesDisabled:
                conflictCard(icon: "arrow.triangle.2.circlepath", bg: MM.neuBg, line: MM.line, fg: MM.text,
                             title: c.title, detail: c.detail) {
                    smallButton(L("Farklı hareket seç"), fill: MM.card, border: MM.line) { clearPick() }
                    smallButton(L("Yerine geçerek ekle"), fill: MM.accent, ink: MM.accentInk) { save() }
                        .disabled(!canSaveNow(conflicts))
                }
            case .reserved, .unsupported:
                conflictCard(icon: "lock", bg: MM.neuBg, line: MM.line, fg: MM.text,
                             title: LF("Ayrılmış: %@", c.title), detail: c.detail) { EmptyView() }
            case .shadows:
                conflictCard(icon: "info.circle", bg: MM.accentSoft, line: MM.accentLine, fg: MM.accentText,
                             title: L("Genel atamayı ezer"), detail: c.detail) { EmptyView() }
            case .caution:
                conflictCard(icon: "exclamationmark.triangle", bg: MM.warnBg, line: MM.warnLine, fg: MM.warnText,
                             title: c.title, detail: c.detail) { EmptyView() }
            }
        } else {
            conflictCard(icon: "checkmark", bg: MM.accentSoft, line: MM.accentLine, fg: MM.accentText,
                         title: L("Bu hareket serbest"), detail: L("macOS'ta ve BetterTouchTool'da atanmış değil.")) { EmptyView() }
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
                set: { var t = trigger; t[keyPath: kp] = $0; trigger = TriggerOptions.sanitize(t, device: device) })
    }

    /// Seçenekler aygıta göre gelir (trackpad: dokunma / basma / çift dokunma, 3–4 parmak, bölge ve tuş yok).
    @ViewBuilder private var triggerFields: some View {
        Picker(L("Hareket türü"), selection: field(\.kind)) {
            ForEach(TriggerOptions.kinds(device: device), id: \.self) { Text(Self.kindName($0)).tag($0) }
        }
        // Çimdikleme her zaman iki parmak, kenar kaydırma tek parmaktır; seçici gösterilmez.
        if trigger.modifier == .none, trigger.kind != .pinch, trigger.kind != .edgeSlide {
            Picker(L("Parmak"), selection: field(\.fingers)) {
                ForEach(TriggerOptions.fingerChoices(kind: trigger.kind, device: device), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
        }
        let zones = TriggerOptions.zoneChoices(kind: trigger.kind, fingers: trigger.fingers, modifier: trigger.modifier,
                                               device: device)
        if !zones.isEmpty {
            Picker(trigger.kind == .edgeSlide ? L("Kenar") : (device == .trackpad ? L("Köşe") : L("Bölge")),
                   selection: field(\.zone)) {
                ForEach(zones, id: \.self) { Text(Self.zoneName($0)).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        let mods = TriggerOptions.modifierChoices(kind: trigger.kind, device: device)
        if mods.count > 1 {
            Picker(L("Tuş"), selection: field(\.modifier)) {
                ForEach(mods, id: \.self) { Text(Self.modifierName($0)).tag($0) }
            }
        }
        if trigger.kind == .swipe {
            Picker(L("Yön"), selection: field(\.direction)) {
                ForEach(SwipeDirection.allCases, id: \.self) { Text(Self.directionName($0)).tag($0) }
            }
        }
    }

    private static func kindName(_ k: GestureKind) -> String {
        switch k {
        case .press: return L("Bas")
        case .tap: return L("Dokun")
        case .doubleTap: return L("Çift dokun")
        case .swipe: return L("Kaydır")
        case .pinch: return L("Çimdikle")
        case .edgeSlide: return L("Kenarda kaydır")
        case .hold: return L("Basılı tut")
        }
    }

    private static func zoneName(_ z: Zone) -> String {
        switch z {
        case .any: return L("Herhangi")
        case .left: return L("Sol")
        case .center: return L("Orta")
        case .right: return L("Sağ")
        case .rear: return L("Arka (logo)")
        case .leftEdge: return L("Sol kenar")
        case .rightEdge: return L("Sağ kenar")
        case .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight: return z.displayName
        }
    }

    private static func modifierName(_ m: PressModifier) -> String {
        switch m {
        case .none: return L("Yok")
        case .fn: return "Fn"
        case .option: return "⌥ Option"
        case .command: return "⌘ Command"
        case .shift: return "⇧ Shift"
        }
    }

    private static func directionName(_ d: SwipeDirection) -> String {
        switch d {
        case .up: return L("Yukarı (öne)")
        case .down: return L("Aşağı")
        case .left: return L("Sola")
        case .right: return L("Sağa")
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
            Picker(L("Kapsam"), selection: .constant("")) {
                Text(L("Tüm uygulamalar")).tag("")
            }
            .disabled(true)
            Text(L("Temel hareketler tüm uygulamalarda geçerlidir. Bir uygulamaya özel davranış için Uygulama profillerinden yeni hareket ekle."))
                .font(.system(size: 12)).foregroundStyle(MM.text2)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            scopePicker
        }
    }

    @ViewBuilder private var scopePicker: some View {
        Picker(L("Kapsam"), selection: Binding<String>(
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
            Text(L("Tüm uygulamalar")).tag("")
            ForEach(scopeOptions) { Text($0.name).tag($0.id) }
            Divider()
            Text(L("Diğer uygulama…")).tag(Self.otherTag)
        }
    }
}
