import SwiftUI
import MerlinCore

/// Uygulamaya özel profiller.
struct ProfilesPage: View {
    @ObservedObject private var store = BindingStore.shared
    @State private var selection: String?
    @State private var extra: [AppChoice] = []
    @State private var adding = false

    /// Kapsamlı ataması olan ya da elle eklenen uygulamalar.
    private var apps: [AppChoice] {
        var seen = Set<String>()
        var out: [AppChoice] = []
        for b in store.bindings {
            if let id = b.appBundleID, seen.insert(id).inserted {
                out.append(AppChoice(id: id, name: b.appName ?? id))
            }
        }
        for e in extra where seen.insert(e.id).inserted { out.append(e) }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                List(apps, selection: $selection) { app in
                    Text(app.name).tag(app.id as String?)
                }
                Menu("Uygulama ekle") {
                    ForEach(AppPicker.runningApps()) { app in
                        Button(app.name) { add(app) }
                    }
                    Divider()
                    Button("Diğer uygulama…") {
                        if let p = AppPicker.pickApp(), let id = p.bundleID {
                            add(AppChoice(id: id, name: p.name))
                        }
                    }
                }
                .padding([.horizontal, .bottom], 8)
            }
            .frame(width: 230)
            Divider()
            detail.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $adding) {
            if let app = apps.first(where: { $0.id == selection }) {
                BindingEditorView(existing: nil, presetScope: app)
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if let app = apps.first(where: { $0.id == selection }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(app.name).font(.title2.weight(.semibold))
                    Spacer()
                    Button("Bu uygulama için hareket ekle") { adding = true }
                }
                BindingListView(scope: app.id)
            }
            .padding(20)
        } else {
            Text(apps.isEmpty
                 ? "Henüz uygulamaya özel profil yok. Bir uygulamada genel atamadan farklı davranmak için \"Uygulama ekle\" ile başla; o uygulamadaki atamalar genel atamaların önüne geçer."
                 : "Soldan bir uygulama seç.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(40)
        }
    }

    private func add(_ app: AppChoice) {
        if !extra.contains(app) { extra.append(app) }
        selection = app.id
    }
}
