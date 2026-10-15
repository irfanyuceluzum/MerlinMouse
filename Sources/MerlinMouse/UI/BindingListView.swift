import SwiftUI
import MerlinCore

extension GestureBinding: Identifiable {}

/// Verilen kapsamdaki atamaların listesi (nil = genel; aksi uygulama kimliği).
struct BindingListView: View {
    let scope: String?
    @ObservedObject private var store = BindingStore.shared
    @State private var editing: GestureBinding?
    @State private var deleting: GestureBinding?

    private var items: [GestureBinding] { store.bindings.filter { $0.appBundleID == scope } }

    var body: some View {
        let env = AppModel.shared.conflictEnvironment()
        Group {
            if items.isEmpty {
                Text("Bu kapsamda henüz atama yok.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { b in row(b, env: env) }
            }
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

    private func row(_ b: GestureBinding, env: ConflictEnvironment) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(b.trigger.title).font(.callout.weight(.medium))
                Text(b.action.title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            badge(for: b, env: env)
            Toggle("Açık", isOn: Binding(get: { b.enabled }, set: { store.setEnabled(id: b.id, $0) }))
                .toggleStyle(.switch).labelsHidden().controlSize(.mini)
            Button("Düzenle") { editing = b }.controlSize(.small)
            Button("Sil", role: .destructive) { deleting = b }.controlSize(.small)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { editing = b }
    }

    private func badge(for b: GestureBinding, env: ConflictEnvironment) -> some View {
        let conflicts = ConflictChecker.check(b, among: store.bindings, env: env)
        let worst = conflicts.min {
            (ConflictLevel.allCases.firstIndex(of: $0.level) ?? 0) < (ConflictLevel.allCases.firstIndex(of: $1.level) ?? 0)
        }
        let text = worst?.title ?? "Serbest"
        let color = worst.map { ConflictStyle.color($0.level) } ?? Color.merlinAccent
        return Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Çakışma düzeylerinin renkleri.
enum ConflictStyle {
    static func color(_ level: ConflictLevel) -> Color {
        switch level {
        case .reserved, .unsupported, .duplicate: return .red
        case .macOS, .caution: return .merlinWarn
        case .btt: return .merlinBTT
        }
    }
}
