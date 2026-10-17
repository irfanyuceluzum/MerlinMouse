import SwiftUI
import MerlinCore

/// Düzenleyicinin hazır hareket ızgarası: aygıtın hazır kartları, (farede) kenar kaydırmalar ve "Özel hareket…".
/// Seçim durumu düzenleyicide tutulur.
struct EditorTriggerGrid: View {
    let device: InputDeviceKind
    /// Seçili eylem türü (kart durumunda uymayan tür kendi varsayılan eylemiyle denetlenir).
    let kind: EditorActionKind
    let env: ConflictEnvironment
    /// Verilen tetikle düzenlenen atama (aygıt korunur).
    let makeBinding: (Trigger) -> GestureBinding
    @Binding var trigger: Trigger
    @Binding var custom: Bool
    @Binding var picked: Bool

    /// Hazır hareket ızgarasındaki tetikler: aygıtın hazırları ve (yalnız farede) iki kenar kaydırma.
    private static let mouseEdgeTriggers = [Trigger(kind: .edgeSlide, zone: .leftEdge).normalized,
                                            Trigger(kind: .edgeSlide, zone: .rightEdge).normalized]
    private static func edgeTriggers(for device: InputDeviceKind) -> [Trigger] {
        device == .magicMouse ? mouseEdgeTriggers : []
    }
    static func isPreset(_ t: Trigger, device: InputDeviceKind) -> Bool {
        let n = t.normalized
        return GesturePresets.presets(for: device).contains { $0.trigger == n } || edgeTriggers(for: device).contains(n)
    }

    private func cardStatus(_ t: Trigger) -> (text: String, dot: Color) {
        // Seçili eylem bu türe uymuyorsa (örn. kenar kartında orta tıklama), türün varsayılan eylemiyle bakılır;
        // tür değişince eylem de ona döner.
        var probe = makeBinding(t)
        if !EditorActionKind.choices(for: t.kind).contains(kind) {
            switch t.kind {
            case .pinch: probe.action = .zoom(style: .gesture, modifiers: [])
            case .edgeSlide: probe.action = .volume
            default: probe.action = .middleClick
            }
        }
        let conflicts = ConflictChecker.check(probe, among: BindingStore.shared.bindings, env: env)
        switch BindingValidation.heaviest(conflicts)?.level {
        case .reserved, .unsupported: return (L("Ayrılmış"), MM.text2)
        case .duplicate: return (L("Zaten atanmış"), MM.text2)
        case .replacesDisabled: return (L("Kapalı ataması var"), MM.text2)
        case .macOS: return (L("macOS kullanıyor"), MM.warnDot)
        case .btt: return (L("BetterTouchTool'da atanmış"), MM.bttDot)
        default: return (L("Serbest"), MM.accent)
        }
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(Array(GesturePresets.presets(for: device).enumerated()), id: \.offset) { _, p in
                let st = cardStatus(p.trigger)
                gestureCard(title: p.title, status: st.text, dot: st.dot, glyph: p.trigger,
                            selected: picked && !custom && trigger.normalized == p.trigger) {
                    trigger = p.trigger
                    custom = false
                    picked = true
                }
            }
            ForEach(Self.edgeTriggers(for: device), id: \.self) { t in
                let st = cardStatus(t)
                gestureCard(title: t.title, status: st.text, dot: st.dot, glyph: t,
                            selected: picked && !custom && trigger.normalized == t) {
                    trigger = t
                    custom = false
                    picked = true
                }
            }
            gestureCard(title: L("Özel hareket…"),
                        status: device == .trackpad ? L("Tür ve parmak sayısını kendin seç") : L("Tür, parmak ve bölgeyi kendin seç"),
                        dot: nil,
                        glyph: picked && custom ? trigger : nil, selected: picked && custom) {
                custom = true
                picked = true
            }
        }
    }

    /// `glyph` nil ise (özel hareket seçilmemişken) simge yerine ayar simgesi durur; hizalama bozulmaz.
    private func gestureCard(title: String, status: String, dot: Color?, glyph: Trigger?, selected: Bool,
                             action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                if let glyph {
                    GestureGlyphView(trigger: glyph, device: device)
                } else {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MM.text2)
                        .frame(width: CGFloat(GestureGlyph.width), height: CGFloat(GestureGlyph.height))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(MM.text).lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                        if let dot { Circle().fill(dot).frame(width: 10, height: 10) }
                    }
                    Text(status).font(.system(size: 12)).foregroundStyle(MM.text2).lineLimit(1)
                }
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
}
