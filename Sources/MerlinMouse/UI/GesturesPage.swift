import SwiftUI
import MerlinCore

/// Genel (tüm uygulamalar) hareket atamaları.
struct GesturesPage: View {
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var store = BindingStore.shared
    @ObservedObject private var s = Settings.shared
    @State private var adding = false

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                MouseMap(touches: model.liveTouches, zoneWidth: 0, flipped: s.flipY,
                         size: CGSize(width: 130, height: 260))
                Text("Parmakların haritada canlı görünür. Ön taraf yukarıda olmalı.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 170)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Hareketler").font(.title2.weight(.semibold))
                    Spacer()
                    Button("Hareket ekle") { adding = true }
                }
                BindingListView(scope: nil)
                if !store.set.preserved.isEmpty {
                    Text("Bu sürümün tanımadığı \(store.set.preserved.count) atama korunuyor")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .sheet(isPresented: $adding) { BindingEditorView(existing: nil) }
    }
}
