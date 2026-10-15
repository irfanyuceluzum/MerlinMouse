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
    @State private var hovered: UUID?

    private var items: [GestureBinding] { store.bindings.filter { $0.appBundleID == scope } }

    var body: some View {
        let env = AppModel.shared.conflictEnvironment()
        Group {
            card(env: env)
        }
        .sheet(item: $editing) { b in BindingEditorView(existing: b) }
        .confirmationDialog("Bu atama silinsin mi?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { b in
            Button("Sil", role: .destructive) { store.remove(id: b.id) }
            Button("Vazgeç", role: .cancel) {}
        } message: { b in
            Text("\(b.trigger.title) → \(b.action.title)")
        }
    }

    // MARK: Kart

    private func card(env: ConflictEnvironment) -> some View {
        MMCard {
            GeometryReader { geo in
                let cols = Columns(total: geo.size.width)
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        MMSectionLabel("Hareket").frame(width: cols.trigger, alignment: .leading)
                        MMSectionLabel("Eylem").frame(width: cols.action, alignment: .leading)
                        MMSectionLabel("Durum").frame(width: cols.status, alignment: .leading)
                        MMSectionLabel("Açık").frame(width: 56, alignment: .leading)
                        Color.clear.frame(width: Columns.editWidth + 12 + Columns.chevronWidth, height: 1)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MM.card2)
                    .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }

                    if items.isEmpty {
                        Text("Bu kapsamda henüz atama yok.")
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
                Text("Orta tuşla sürüklerken Magic Mouse kaydırması engellenir, model istemeden yakınlaşmaz.")
            }
            if !store.set.preserved.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "archivebox").font(.system(size: 13, weight: .medium))
                    Text("Bu sürümün tanımadığı \(store.set.preserved.count) atama korunuyor")
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
        static let chevronWidth: CGFloat = 10
        let trigger: CGFloat, action: CGFloat, status: CGFloat
        init(total: CGFloat) {
            let avail = max(300, total - 40 - 5 * 12 - 56 - Columns.editWidth - Columns.chevronWidth)
            let unit = avail / 5.1
            trigger = unit * 2.2; action = unit * 1.5; status = unit * 1.4
        }
    }

    private func subtitle(_ b: GestureBinding, conflicts: [Conflict], kind: BindingStatusKind) -> (String, Bool) {
        if kind == .macOS, let c = conflicts.first(where: { $0.level == .macOS }) { return (c.detail, true) }
        if kind == .disabled { return ("Kapalı", false) }
        let t = b.trigger.normalized
        if t.modifier != .none { return ("Klavye + fare", false) }
        let fingers: String
        switch t.fingers {
        case 1: fingers = "Tek parmak"
        case 2: fingers = "İki parmak"
        case 3: fingers = "Üç parmak"
        case let n: fingers = "\(n) parmak"
        }
        switch t.kind {
        case .press, .hold: return ("\(fingers) · fiziksel tıklama", false)
        case .tap: return ("Basmadan, hafif dokunuş", false)
        case .doubleTap: return ("Basmadan, çift dokunuş", false)
        case .swipe: return ("\(fingers) · kaydırma", false)
        }
    }

    private func gridRow(_ b: GestureBinding, env: ConflictEnvironment, cols: Columns) -> some View {
        let conflicts = ConflictChecker.check(b, among: store.bindings, env: env)
        let kind = BindingStatus.kind(enabled: b.enabled, conflicts: conflicts)
        let sub = subtitle(b, conflicts: conflicts, kind: kind)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(b.trigger.title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                Text(sub.0).font(.system(size: 12)).foregroundStyle(sub.1 ? MM.warnText : MM.text2)
                    .lineLimit(2)
            }
            .frame(width: cols.trigger, alignment: .leading)
            Text(b.action.title).font(.system(size: 13.5)).foregroundStyle(MM.text)
                .frame(width: cols.action, alignment: .leading)
            MMStatusBadge(kind: kind, label: kind == .blocked ? blockedLabel(conflicts) : nil)
                .frame(width: cols.status, alignment: .leading)
            MMSwitch(isOn: Binding(get: { b.enabled }, set: { store.setEnabled(id: b.id, $0) }),
                     label: "\(b.trigger.title) hareketi")
                .frame(width: 56, alignment: .leading)
            Button { editing = b } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil").font(.system(size: 11, weight: .semibold))
                    Text("Düzenle").font(.system(size: 12))
                }
                .foregroundStyle(MM.text)
                .padding(.horizontal, 9).frame(width: Columns.editWidth, height: 26)
                .background(MM.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(MM.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(b.trigger.title) hareketini düzenle")
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
        .accessibilityHint("\(b.trigger.title) hareketini düzenle")
        .contextMenu {
            Button("Düzenle") { editing = b }
            Button("Sil", role: .destructive) { deleting = b }
        }
    }

    private func blockedLabel(_ conflicts: [Conflict]) -> String {
        switch conflicts.first(where: { $0.level.blocksSave })?.level {
        case .unsupported: return "Desteklenmiyor"
        case .duplicate: return "Yinelenen"
        default: return "Ayrılmış"
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
