import SwiftUI
import AppKit
import MerlinCore

extension GestureBinding: Identifiable {}

/// Verilen kapsamdaki atamaların kart listesi (nil = genel; aksi uygulama kimliği, altbilgisiz).
struct BindingListView: View {
    let scope: String?
    @ObservedObject private var store = BindingStore.shared
    @State private var editing: GestureBinding?
    @State private var deleting: GestureBinding?
    @State private var resetting: GestureBinding?
    @State private var hovered: UUID?

    private var items: [GestureBinding] { store.bindings.filter { $0.appBundleID == scope } }

    var body: some View {
        let env = AppModel.shared.conflictEnvironment()
        Group {
            card(env: env)
        }
        .sheet(item: $editing) { b in BindingEditorView(existing: b) }
        .confirmationDialog(L("Bu atama silinsin mi?"), isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { b in
            Button(L("Sil"), role: .destructive) { store.remove(id: b.id) }
            Button(L("Vazgeç"), role: .cancel) {}
        } message: { b in
            Text(verbatim: "\(b.trigger.title) → \(b.action.title)")
        }
        .confirmationDialog(L("Varsayılana sıfırlansın mı?"), isPresented: Binding(
            get: { resetting != nil }, set: { if !$0 { resetting = nil } }), presenting: resetting) { b in
            Button(L("Varsayılana sıfırla")) { store.resetToDefault(id: b.id) }
            Button(L("Vazgeç"), role: .cancel) {}
        } message: { b in
            Text(L("Temel hareketin tetiği ve eylemi ilk kurulumdaki hâline döner."))
        }
    }

    // MARK: Kart

    private func card(env: ConflictEnvironment) -> some View {
        MMCard {
            GeometryReader { geo in
                let cols = Columns(total: geo.size.width)
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        MMSectionLabel(L("Hareket")).frame(width: Columns.glyphWidth + cols.trigger, alignment: .leading)
                        MMSectionLabel(L("Eylem")).frame(width: cols.action, alignment: .leading)
                        MMSectionLabel(L("Durum")).frame(width: cols.status, alignment: .leading)
                        MMSectionLabel(L("Açık")).frame(width: 56, alignment: .leading)
                        Color.clear.frame(width: Columns.editWidth + Columns.trashWidth + 24 + Columns.chevronWidth, height: 1)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MM.card2)
                    .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }

                    if items.isEmpty {
                        Text(L("Bu kapsamda henüz atama yok."))
                            .font(.callout).foregroundStyle(MM.text2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(items) { b in gridRow(b, env: env, cols: cols) }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if scope == nil { footer }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle").font(.system(size: 13, weight: .medium))
                Text(L("Orta tuşla sürüklerken Magic Mouse kaydırması engellenir, model istemeden yakınlaşmaz."))
            }
            if !store.set.preserved.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "archivebox").font(.system(size: 13, weight: .medium))
                    Text(LF("Bu sürümün tanımadığı %lld atama korunuyor", store.set.preserved.count))
                }
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(MM.text2)
        .padding(.horizontal, 20).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MM.card2)
        .overlay(alignment: .top) { Rectangle().fill(MM.line).frame(height: 1) }
    }

    private struct Columns {
        static let editWidth: CGFloat = 82
        static let trashWidth: CGFloat = 26
        static let chevronWidth: CGFloat = 10
        /// Hareket simgesi (28) + başlıkla arası (10); hareket sütununa eklenir.
        static let glyphWidth: CGFloat = 28 + 10
        let trigger: CGFloat, action: CGFloat, status: CGFloat
        init(total: CGFloat) {
            let avail = max(300, total - 40 - 6 * 12 - 56 - Columns.editWidth - Columns.trashWidth - Columns.chevronWidth
                - Columns.glyphWidth)
            // Durum sütunu en uzun rozeti ("macOS ile çakışıyor") sığdıracak kadar geniş kalır.
            let st = max(avail / 5.1 * 1.4, 176)
            let unit = (avail - st) / 3.9
            trigger = unit * 2.6; action = unit * 1.3; status = st
        }
    }

    private func subtitle(_ b: GestureBinding, conflicts: [Conflict], kind: BindingStatusKind) -> (String, Bool) {
        if kind == .macOS, let c = conflicts.first(where: { $0.level == .macOS }) { return (c.detail, true) }
        if kind == .disabled { return (L("Kapalı"), false) }
        let t = b.trigger.normalized
        if t.modifier != .none { return (L("Klavye + fare"), false) }
        let fingers: String
        switch t.fingers {
        case 1: fingers = L("Tek parmak")
        case 2: fingers = L("İki parmak")
        case 3: fingers = L("Üç parmak")
        case let n: fingers = LF("%lld parmak", n)
        }
        switch t.kind {
        case .press, .hold: return (LF("%@ · fiziksel tıklama", fingers), false)
        case .tap: return (L("Basmadan, hafif dokunuş"), false)
        case .doubleTap: return (L("Basmadan, çift dokunuş"), false)
        case .swipe: return (LF("%@ · kaydırma", fingers), false)
        case .pinch: return (LF("%@ · çimdikleme", fingers), false)
        case .edgeSlide: return (L("Tek parmak · kenar şeridi"), false)
        }
    }

    private func gridRow(_ b: GestureBinding, env: ConflictEnvironment, cols: Columns) -> some View {
        let conflicts = ConflictChecker.check(b, among: store.bindings, env: env)
        let kind = BindingStatus.kind(enabled: b.enabled, conflicts: conflicts)
        let sub = subtitle(b, conflicts: conflicts, kind: kind)
        return HStack(spacing: 12) {
            HStack(spacing: 10) {
                GestureGlyphView(trigger: b.trigger)
                VStack(alignment: .leading, spacing: 3) {
                    Text(b.trigger.title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                        .lineLimit(1).minimumScaleFactor(0.85)
                    HStack(spacing: 6) {
                        if b.isBuiltIn { builtInTag }
                        Text(sub.0).font(.system(size: 12)).foregroundStyle(sub.1 ? MM.warnText : MM.text2)
                            .lineLimit(2)
                    }
                }
                .frame(width: cols.trigger, alignment: .leading)
            }
            .frame(width: Columns.glyphWidth + cols.trigger, alignment: .leading)
            Text(b.action.title).font(.system(size: 13.5)).foregroundStyle(MM.text)
                .frame(width: cols.action, alignment: .leading)
            MMStatusBadge(kind: kind, label: kind == .blocked ? blockedLabel(conflicts) : (kind == .replacesDisabled ? L("Kapalı kopya") : nil))
                .frame(width: cols.status, alignment: .leading)
            MMSwitch(isOn: Binding(get: { b.enabled }, set: { store.setEnabled(id: b.id, $0) }),
                     label: LF("%@ hareketi", b.trigger.title))
                .frame(width: 56, alignment: .leading)
            Button { editing = b } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil").font(.system(size: 11, weight: .semibold))
                    Text(L("Düzenle")).font(.system(size: 12))
                }
                .foregroundStyle(MM.text)
                .padding(.horizontal, 9).frame(width: Columns.editWidth, height: 26)
                .background(MM.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(MM.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(LF("%@ hareketini düzenle", b.trigger.title))
            Group {
                if b.isBuiltIn {
                    Color.clear
                } else {
                    Button { deleting = b } label: {
                        Image(systemName: "trash").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MM.text2)
                            .frame(width: Columns.trashWidth, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(L("Atamayı sil"))
                    .accessibilityLabel(LF("%@ hareketini sil", b.trigger.title))
                }
            }
            .frame(width: Columns.trashWidth, height: 26)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MM.text2).frame(width: Columns.chevronWidth)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hovered == b.id ? MM.card2 : (kind == .macOS ? MM.warnBg : Color.clear))
        .overlay(alignment: .bottom) { Rectangle().fill(MM.line2).frame(height: 1) }
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { hovered = b.id; NSCursor.pointingHand.push() } else {
                if hovered == b.id { hovered = nil }
                NSCursor.pop()
            }
        }
        .onTapGesture { editing = b }
        .accessibilityElement(children: .contain)
        .accessibilityHint(LF("%@ hareketini düzenle", b.trigger.title))
        .contextMenu {
            Button(L("Düzenle")) { editing = b }
            if b.isBuiltIn {
                Button(L("Varsayılana sıfırla")) { resetting = b }
            } else {
                Button(L("Sil"), role: .destructive) { deleting = b }
            }
        }
    }

    private var builtInTag: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill").font(.system(size: 8, weight: .semibold))
            Text(L("Temel")).font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(MM.text2)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(MM.neuBg, in: Capsule())
        .help(L("Temel hareket: silinemez, kapatılabilir ve varsayılana sıfırlanabilir."))
    }

    private func blockedLabel(_ conflicts: [Conflict]) -> String {
        switch conflicts.first(where: { $0.level.blocksSave })?.level {
        case .unsupported: return L("Desteklenmiyor")
        case .duplicate: return L("Yinelenen")
        default: return L("Ayrılmış")
        }
    }
}

/// Çakışma düzeylerinin renkleri.
enum ConflictStyle {
    static func color(_ level: ConflictLevel) -> Color {
        switch level {
        case .reserved, .unsupported, .duplicate: return .red
        case .macOS, .caution: return MM.warnText
        case .btt: return MM.bttText
        case .shadows, .replacesDisabled: return .secondary
        }
    }
}
